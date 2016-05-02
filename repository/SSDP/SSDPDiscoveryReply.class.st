"
This message is sent by a server directly to the requesting socket when a client  requests the available services of a certain type.
"
Class {
	#name : #SSDPDiscoveryReply,
	#superclass : #SSDPMessage,
	#instVars : [
		'location',
		'serverInfo',
		'discoveryTime',
		'maxAge'
	],
	#category : #'SSDP-Core'
}

{ #category : #testing }
SSDPDiscoveryReply class >> represents: aDatagram [
	"Discovery responses must always have status 200 OK"
	^aDatagram beginsWith: 'HTTP/1.1 200 OK'
	
]

{ #category : #conversion }
SSDPDiscoveryReply >> asService [
	^SSDPService new merge: self
]

{ #category : #accessing }
SSDPDiscoveryReply >> discoveryTime [
	^discoveryTime
]

{ #category : #'initialize - release' }
SSDPDiscoveryReply >> initializeFrom: aDatagram [ 
	| response cacheParams |
	response := ZnResponse readFrom: aDatagram readStream.
	"If the response was not 200 OK, we are required to disregard it"
	response status = 200 ifFalse: [ ^nil ].
	"Obligatory SSDP fields"
	serviceType := response headers at: 'St'.
	uniqueServiceName := response headers at: 'Usn'.
	"Common SSDP fields"
	serverInfo := response headers at: 'Server' ifAbsent: nil.
	location := response headers at: 'Location' ifAbsent: nil.
	"Cache control fields"
		"TODO: Convert time field when present to DateAndTime"
	discoveryTime := response headers at:'Date' ifAbsent: [ DateAndTime now].
	
	cacheParams := $, split: ((response headers at: 'Cache-control' ifAbsent: [''])) .
	maxAge := ( $= split: (cacheParams detect: [:one | one beginsWith: 'max-age'] ifNone: '0')) last asNumber asDuration.
	


	
	
]

{ #category : #accessing }
SSDPDiscoveryReply >> location [
	^location
]

{ #category : #accessing }
SSDPDiscoveryReply >> maxAge [
	^maxAge
]

{ #category : #accessing }
SSDPDiscoveryReply >> serverInfo [
	^serverInfo
]

{ #category : #handling }
SSDPDiscoveryReply >> serviceChangeIn: aCache [
self halt.
	^aCache updateServiceFor: self
]
