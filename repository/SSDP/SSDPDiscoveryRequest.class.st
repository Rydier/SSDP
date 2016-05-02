"
This message is sent by a client to the multicast address in order to trigger responses from available servers that implement the serviceType the client is interested in.
"
Class {
	#name : #SSDPDiscoveryRequest,
	#superclass : #SSDPMessage,
	#instVars : [
		'timeout'
	],
	#category : #'SSDP-Core'
}

{ #category : #testing }
SSDPDiscoveryRequest class >> represents: aDatagram [
	"Discovery responses must always have status 200 OK"
	^aDatagram beginsWith: 'M-SEARCH * HTTP/1.1'
]

{ #category : #'initialize - release' }
SSDPDiscoveryRequest >> initializeFrom: aDatagram [
| stream headers  |
	stream := aDatagram asString readStream.
	stream nextLine trim = 'M-SEARCH * HTTP/1.1' ifFalse: [ ^nil ].
	headers := ZnHeaders readFrom: stream.
	(headers at: 'Man') = '"ssdp:discover"' ifFalse: [ ^nil ].
	serviceType :=  headers at: 'St'.
	"Send within 1 second by default"
	timeout := (headers at:'Mx' ifAbsent: [1]) asNumber asDuration.
	
]

{ #category : #handling }
SSDPDiscoveryRequest >> serviceChangeIn: aCache [
	"Discovery requests are not to be handled as an entry to cache"
	^nil
]

{ #category : #accessing }
SSDPDiscoveryRequest >> timeout [
	^timeout
]
