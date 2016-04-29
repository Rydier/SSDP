"
This message  is sent to the multicast address by a server when a service is purposefully shut down, and clients can be notified that it will no longer be available.
"
Class {
	#name : #SSDPUnavailable,
	#superclass : #SSDPMessage,
	#category : #'SSDP-Core'
}

{ #category : #testing }
SSDPUnavailable class >> represents: aDatagram [
	"Available responses must always use the NOTIFY method"

	^ aDatagram
		beginsWith: 'NOTIFY * HTTP/1.1' asByteArray
		and:
			[ "Hacky, potentially wrong if there's two fields of value ssdp:alive, but let's not do full header parsing twice..."
			(aDatagram indexOfSubCollection: 'ssdp:byebye' asByteArray) > 0 ]	
]

{ #category : #handling }
SSDPUnavailable >> deliver: service ifAvailable: whenAvailable ifUnavailable: whenByeBye [
	whenByeBye value: service
]

{ #category : #'initialize - release' }
SSDPUnavailable >> initializeFrom: aDatagram [
	| stream headers |
	stream := aDatagram readStream.
	stream nextLine trim = 'NOTIFY * HTTP/1.1' ifFalse: [ ^nil ].
	headers := ZnHeaders readFrom: stream.
	(headers at: 'Nts' = 'ssdp:byebye') ifFalse: [ ^nil ].
	"Obligatory SSDP notify fields"
	serviceType :=  headers at: 'Nt'.
	uniqueServiceName :=  headers at: 'Usn'.
]

{ #category : #handling }
SSDPUnavailable >> serviceChangeIn: aCache [
	^aCache removeService: self
]
