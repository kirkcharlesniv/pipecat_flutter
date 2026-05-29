package com.kcniverba

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LocalMicStateControllerTest {
    @Test
    fun enable_waitsForObservedInputThenPublishing() {
        val delegate = FakeDelegate(
            snapshot = LocalMicSnapshot(inputEnabled = false, publishingEnabled = false),
        )
        val controller = LocalMicStateController(delegate)
        var completion: Result<Unit>? = null

        controller.updateDesiredEnabled(true) { completion = it }

        assertEquals(listOf("input:true"), delegate.operations)
        assertNull(completion)

        delegate.completeNextRequest(Result.success(Unit))
        assertEquals(1, delegate.scheduledCount)

        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = true, publishingEnabled = false))
        assertEquals(listOf("input:true", "publish:true"), delegate.operations)
        assertFalse(controller.currentMicEnabled(fallback = true))

        delegate.completeNextRequest(Result.success(Unit))
        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = true, publishingEnabled = true))

        assertNotNull(completion)
        assertTrue(completion!!.isSuccess)
        assertFalse(controller.isTransitioning)
        assertTrue(controller.isSendingAudio)
    }

    @Test
    fun disable_waitsForObservedPublishingThenInput() {
        val delegate = FakeDelegate(
            snapshot = LocalMicSnapshot(inputEnabled = true, publishingEnabled = true),
        )
        val controller = LocalMicStateController(delegate)
        var completion: Result<Unit>? = null

        controller.updateDesiredEnabled(false) { completion = it }

        assertEquals(listOf("publish:false"), delegate.operations)
        assertNull(completion)

        delegate.completeNextRequest(Result.success(Unit))
        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = true, publishingEnabled = false))
        assertEquals(listOf("publish:false", "input:false"), delegate.operations)
        assertFalse(controller.currentMicEnabled(fallback = true))

        delegate.completeNextRequest(Result.success(Unit))
        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = false, publishingEnabled = false))

        assertNotNull(completion)
        assertTrue(completion!!.isSuccess)
        assertFalse(controller.isTransitioning)
        assertFalse(controller.isSendingAudio)
    }

    @Test
    fun rapidToggle_restartsFromLatestObservedSnapshot() {
        val delegate = FakeDelegate(
            snapshot = LocalMicSnapshot(inputEnabled = true, publishingEnabled = false),
        )
        val controller = LocalMicStateController(delegate)
        var firstCompletion: Result<Unit>? = null
        var secondCompletion: Result<Unit>? = null

        controller.updateDesiredEnabled(false) { firstCompletion = it }
        assertEquals(listOf("input:false"), delegate.operations)

        controller.updateDesiredEnabled(true) { secondCompletion = it }

        assertNotNull(firstCompletion)
        assertTrue(firstCompletion!!.isSuccess)
        assertEquals(listOf("input:false", "publish:true"), delegate.operations)
        assertNull(secondCompletion)

        delegate.completeNextRequest(Result.success(Unit))
        assertNull(secondCompletion)

        delegate.completeNextRequest(Result.success(Unit))
        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = true, publishingEnabled = true))

        assertNotNull(secondCompletion)
        assertTrue(secondCompletion!!.isSuccess)
        assertTrue(controller.isSendingAudio)
    }

    @Test
    fun polling_reappliesOnceThenFails() {
        val delegate = FakeDelegate(
            snapshot = LocalMicSnapshot(inputEnabled = false, publishingEnabled = false),
        )
        val controller = LocalMicStateController(
            delegate = delegate,
            config = LocalMicStateControllerConfig(
                pollIntervalMs = 1,
                maxPollAttempts = 2,
            ),
        )
        var completion: Result<Unit>? = null

        controller.updateDesiredEnabled(true) { completion = it }
        assertEquals(listOf("input:true"), delegate.operations)

        delegate.completeNextRequest(Result.success(Unit))
        delegate.runNextScheduledAction()
        delegate.runNextScheduledAction()
        assertEquals(listOf("input:true", "input:true"), delegate.operations)

        delegate.completeNextRequest(Result.success(Unit))
        delegate.runNextScheduledAction()
        delegate.runNextScheduledAction()

        val failure = completion?.exceptionOrNull()
        val error = assertIs<LocalMicStateControllerError>(failure)
        assertEquals("MIC_RECONCILE_ERROR", error.code)
        assertFalse(controller.isTransitioning)
    }

    @Test
    fun observedDrift_selfHealsWhileIdle() {
        val delegate = FakeDelegate(
            snapshot = LocalMicSnapshot(inputEnabled = true, publishingEnabled = true),
        )
        val controller = LocalMicStateController(delegate)

        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = true, publishingEnabled = true))
        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = true, publishingEnabled = false))

        assertEquals(listOf("publish:true"), delegate.operations)

        delegate.completeNextRequest(Result.success(Unit))
        controller.observeSnapshot(LocalMicSnapshot(inputEnabled = true, publishingEnabled = true))

        assertFalse(controller.isTransitioning)
        assertTrue(controller.isSendingAudio)
    }

    private class FakeDelegate(
        var snapshot: LocalMicSnapshot? = null,
    ) : LocalMicStateControllerDelegate {
        data class PendingRequest(
            val operation: String,
            val completion: (Result<Unit>) -> Unit,
        )

        val operations = mutableListOf<String>()
        private val pendingRequests = ArrayDeque<PendingRequest>()
        private val scheduledTasks = ArrayDeque<FakeScheduledTask>()

        val scheduledCount: Int
            get() = scheduledTasks.count { !it.isCancelled }

        override fun issueSetInputEnabled(
            enabled: Boolean,
            completion: (Result<Unit>) -> Unit,
        ) {
            operations += "input:$enabled"
            pendingRequests += PendingRequest("input:$enabled", completion)
        }

        override fun issueSetPublishingEnabled(
            enabled: Boolean,
            completion: (Result<Unit>) -> Unit,
        ) {
            operations += "publish:$enabled"
            pendingRequests += PendingRequest("publish:$enabled", completion)
        }

        override fun readSnapshot(): LocalMicSnapshot? {
            return snapshot
        }

        override fun schedule(delayMs: Long, action: () -> Unit): LocalMicScheduledTask {
            val task = FakeScheduledTask(action)
            scheduledTasks += task
            return task
        }

        fun completeNextRequest(result: Result<Unit>) {
            val request = pendingRequests.removeFirstOrNull()
            requireNotNull(request) { "No pending request to complete." }
            request.completion(result)
        }

        fun runNextScheduledAction() {
            while (scheduledTasks.isNotEmpty()) {
                val task = scheduledTasks.removeFirst()
                if (!task.isCancelled) {
                    task.run()
                    return
                }
            }
            error("No scheduled action to run.")
        }
    }

    private class FakeScheduledTask(
        private val action: () -> Unit,
    ) : LocalMicScheduledTask {
        var isCancelled: Boolean = false
            private set

        override fun cancel() {
            isCancelled = true
        }

        fun run() {
            if (!isCancelled) {
                action()
            }
        }
    }
}
