package com.kcniverba

internal data class LocalMicSnapshot(
    val inputEnabled: Boolean,
    val publishingEnabled: Boolean,
) {
    val isSending: Boolean
        get() = inputEnabled && publishingEnabled

    fun matchesDesired(enabled: Boolean): Boolean {
        return inputEnabled == enabled && publishingEnabled == enabled
    }
}

internal data class LocalMicStateControllerConfig(
    val pollIntervalMs: Long = 100,
    val maxPollAttempts: Int = 10,
)

internal class LocalMicStateControllerError(
    val code: String,
    override val message: String,
) : RuntimeException(message)

internal interface LocalMicStateControllerDelegate {
    fun issueSetInputEnabled(enabled: Boolean, completion: (Result<Unit>) -> Unit)
    fun issueSetPublishingEnabled(enabled: Boolean, completion: (Result<Unit>) -> Unit)
    fun readSnapshot(): LocalMicSnapshot?
    fun schedule(delayMs: Long, action: () -> Unit): LocalMicScheduledTask

    /**
     * Called whenever the observed "is sending audio" state changes, including
     * poll-driven convergence that no transport callback would surface. Lets the
     * plugin re-emit the authoritative mic state to Flutter.
     */
    fun onSendingStateChanged(isSending: Boolean)
}

internal fun interface LocalMicScheduledTask {
    fun cancel()
}

internal class LocalMicStateController(
    private val delegate: LocalMicStateControllerDelegate,
    private val config: LocalMicStateControllerConfig = LocalMicStateControllerConfig(),
) {
    enum class Phase {
        IDLE,
        WAITING_FOR_INPUT_ENABLE,
        WAITING_FOR_PUBLISH_ENABLE,
        WAITING_FOR_PUBLISH_DISABLE,
        WAITING_FOR_INPUT_DISABLE,
    }

    private data class Transition(
        val generation: Long,
        val phase: Phase,
        val completion: ((Result<Unit>) -> Unit)?,
        val pollAttempts: Int,
        val didReapply: Boolean,
    )

    var desiredEnabled: Boolean = true
        private set

    var observedSnapshot: LocalMicSnapshot? = null
        private set

    val phase: Phase
        get() = transition?.phase ?: Phase.IDLE

    val isTransitioning: Boolean
        get() = transition != null

    val isSendingAudio: Boolean
        get() = observedSnapshot?.isSending == true

    private var generationCounter: Long = 0
    private var transition: Transition? = null
    private var pendingPoll: LocalMicScheduledTask? = null
    private var lastNotifiedIsSending: Boolean? = null

    fun reset(desiredEnabled: Boolean = true) {
        this.desiredEnabled = desiredEnabled
        observedSnapshot = null
        generationCounter += 1
        transition = null
        cancelPendingPoll()
        // Force the next real snapshot to notify, guaranteeing the plugin
        // re-emits the authoritative mic state after a (re)connect.
        lastNotifiedIsSending = null
    }

    fun updateDesiredEnabled(
        enabled: Boolean,
        completion: ((Result<Unit>) -> Unit)? = null,
    ) {
        desiredEnabled = enabled
        val snapshot = refreshSnapshot()
        if (snapshot?.matchesDesired(enabled) == true) {
            completeActiveTransition(Result.success(Unit))
            completion?.invoke(Result.success(Unit))
            return
        }

        cancelActiveTransition(Result.success(Unit))
        startTransition(snapshot = snapshot, completion = completion)
    }

    fun observeSnapshot(snapshot: LocalMicSnapshot) {
        observedSnapshot = snapshot
        notifySendingIfChanged()

        val activeTransition = transition
        if (activeTransition == null) {
            if (!snapshot.matchesDesired(desiredEnabled)) {
                startTransition(snapshot = snapshot, completion = null)
            }
            return
        }

        if (snapshot.matchesDesired(desiredEnabled)) {
            completeActiveTransition(Result.success(Unit))
            return
        }

        if (!phaseSatisfied(activeTransition.phase, snapshot)) {
            return
        }

        val nextPhase = nextPhase(snapshot, desiredEnabled)
        if (nextPhase == null || nextPhase == Phase.IDLE) {
            completeActiveTransition(Result.success(Unit))
            return
        }

        if (nextPhase == activeTransition.phase) {
            return
        }

        cancelPendingPoll()
        transition = activeTransition.copy(
            phase = nextPhase,
            pollAttempts = 0,
            didReapply = false,
        )
        executeCurrentPhase()
    }

    fun currentMicEnabled(fallback: Boolean): Boolean {
        return observedSnapshot?.isSending ?: fallback
    }

    private fun startTransition(
        snapshot: LocalMicSnapshot?,
        completion: ((Result<Unit>) -> Unit)?,
    ) {
        val initialPhase = nextPhase(snapshot, desiredEnabled)
        if (initialPhase == null || initialPhase == Phase.IDLE) {
            completion?.invoke(Result.success(Unit))
            return
        }

        transition = Transition(
            generation = nextGeneration(),
            phase = initialPhase,
            completion = completion,
            pollAttempts = 0,
            didReapply = false,
        )
        executeCurrentPhase()
    }

    private fun executeCurrentPhase() {
        val activeTransition = transition ?: return
        cancelPendingPoll()

        val completion: (Result<Unit>) -> Unit = completion@{ result ->
            val current = transition
            if (current == null || current.generation != activeTransition.generation) {
                return@completion
            }

            if (result.isFailure) {
                completeActiveTransition(result)
                return@completion
            }

            schedulePoll(activeTransition.generation)
        }

        when (activeTransition.phase) {
            Phase.WAITING_FOR_INPUT_ENABLE ->
                delegate.issueSetInputEnabled(enabled = true, completion = completion)

            Phase.WAITING_FOR_PUBLISH_ENABLE ->
                delegate.issueSetPublishingEnabled(enabled = true, completion = completion)

            Phase.WAITING_FOR_PUBLISH_DISABLE ->
                delegate.issueSetPublishingEnabled(enabled = false, completion = completion)

            Phase.WAITING_FOR_INPUT_DISABLE ->
                delegate.issueSetInputEnabled(enabled = false, completion = completion)

            Phase.IDLE -> {
                completeActiveTransition(Result.success(Unit))
            }
        }
    }

    private fun schedulePoll(generation: Long) {
        cancelPendingPoll()
        pendingPoll = delegate.schedule(config.pollIntervalMs) {
            onPoll(generation)
        }
    }

    private fun onPoll(generation: Long) {
        val activeTransition = transition ?: return
        if (activeTransition.generation != generation) {
            return
        }

        refreshSnapshot()?.let { observeSnapshot(it) }

        val current = transition ?: return
        if (current.generation != generation) {
            return
        }

        val attempts = current.pollAttempts + 1
        if (attempts < config.maxPollAttempts) {
            transition = current.copy(pollAttempts = attempts)
            schedulePoll(generation)
            return
        }

        if (!current.didReapply) {
            transition = current.copy(
                pollAttempts = 0,
                didReapply = true,
            )
            executeCurrentPhase()
            return
        }

        completeActiveTransition(
            Result.failure(
                LocalMicStateControllerError(
                    code = "MIC_RECONCILE_ERROR",
                    message = "Daily microphone input/publishing did not reach requested state.",
                )
            )
        )
    }

    private fun refreshSnapshot(): LocalMicSnapshot? {
        val snapshot = delegate.readSnapshot()
        if (snapshot != null) {
            observedSnapshot = snapshot
            notifySendingIfChanged()
        }
        return snapshot
    }

    private fun notifySendingIfChanged() {
        val current = observedSnapshot?.isSending == true
        if (lastNotifiedIsSending != current) {
            lastNotifiedIsSending = current
            delegate.onSendingStateChanged(current)
        }
    }

    private fun completeActiveTransition(result: Result<Unit>) {
        val completion = transition?.completion
        transition = null
        cancelPendingPoll()
        completion?.invoke(result)
    }

    private fun cancelActiveTransition(result: Result<Unit>) {
        val completion = transition?.completion
        transition = null
        cancelPendingPoll()
        completion?.invoke(result)
    }

    private fun cancelPendingPoll() {
        pendingPoll?.cancel()
        pendingPoll = null
    }

    private fun nextGeneration(): Long {
        generationCounter += 1
        return generationCounter
    }

    private fun nextPhase(
        snapshot: LocalMicSnapshot?,
        desiredEnabled: Boolean,
    ): Phase? {
        if (snapshot == null) {
            return if (desiredEnabled) {
                Phase.WAITING_FOR_INPUT_ENABLE
            } else {
                Phase.WAITING_FOR_PUBLISH_DISABLE
            }
        }

        if (desiredEnabled) {
            return when {
                !snapshot.inputEnabled -> Phase.WAITING_FOR_INPUT_ENABLE
                !snapshot.publishingEnabled -> Phase.WAITING_FOR_PUBLISH_ENABLE
                else -> null
            }
        }

        return when {
            snapshot.publishingEnabled -> Phase.WAITING_FOR_PUBLISH_DISABLE
            snapshot.inputEnabled -> Phase.WAITING_FOR_INPUT_DISABLE
            else -> null
        }
    }

    private fun phaseSatisfied(
        phase: Phase,
        snapshot: LocalMicSnapshot,
    ): Boolean {
        return when (phase) {
            Phase.IDLE -> true
            Phase.WAITING_FOR_INPUT_ENABLE -> snapshot.inputEnabled
            Phase.WAITING_FOR_PUBLISH_ENABLE -> snapshot.publishingEnabled
            Phase.WAITING_FOR_PUBLISH_DISABLE -> !snapshot.publishingEnabled
            Phase.WAITING_FOR_INPUT_DISABLE -> !snapshot.inputEnabled
        }
    }
}
