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
	| response headers cacheParams |
	response := ZnResponse readFrom: aDatagram readStream.
	"If the response was not 200 OK, we are required to disregard it"
	response code = 200 ifFalse: [ ^nil ].
	headers := response headers.
	"Obligatory SSDP fields"
	serviceType :=  headers at: 'St'.
	uniqueServiceName :=  headers at: 'Usn'.
	"Common SSDP fields"
	serverInfo :=  headers at: 'Server' ifAbsent: nil.
	location :=  headers at: 'Location' ifAbsent: nil.
	"Cache control fields"
		"Mark:We always use time on local machine rather than value of Date header field.
		This is more consistent with the cache update logic (which compares with local time,
		and saves us having to deal with converting from a string representation of DateAndTime"
	discoveryTime := DateAndTime now.
	
	cacheParams :=  ( headers at: 'Cache-control' ifAbsent: ['']) splitOn: ',' .
	maxAge := ( (cacheParams detect: [:one | one beginsWith: 'max-age'] ifNone: '0') splitOn: '=') last asNumber asDuration.
	


	
	
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

	^aCache updateServiceFor: self
]
