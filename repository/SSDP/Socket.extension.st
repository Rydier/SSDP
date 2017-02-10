Extension { #name : #Socket }

{ #category : #'*SSDP' }
Socket >> waitForDataForMsecs: timeout ifClosed: closedBlock ifTimedOut: timedOutBlock [
	"Seconds resolution is way too much for for instance, UDP sockets running on local network, use this when timeouts > 1 sec is desirable"
	"Wait for the given amount of milliseconds for data to arrive."
	
	| startTime msecsDelta |
	startTime := Time millisecondClockValue.
	msecsDelta := timeout truncated.
	[(Time millisecondsSince: startTime) < msecsDelta] whileTrue: [
		(self primSocketReceiveDataAvailable: socketHandle)
			ifTrue: [^self].
		self isConnected
			ifFalse: [^closedBlock value].
		self readSemaphore waitTimeoutMSecs: 
			(msecsDelta - (Time millisecondsSince: startTime) max: 0).
	].

	(self primSocketReceiveDataAvailable: socketHandle)
		ifFalse: [
			self isConnected
				ifTrue: [^timedOutBlock value]
				ifFalse: [^closedBlock value]].
]
