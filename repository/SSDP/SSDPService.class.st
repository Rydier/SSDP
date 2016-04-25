"
An SSDPService is some resource avilable at a defined location.


"
Class {
	#name : #SSDPService,
	#superclass : #Object,
	#instVars : [
		'location',
		'discoveryTime',
		'maxAge',
		'serviceType',
		'uniqueServiceName',
		'serverInfo',
		'available',
		'notificationTypeSub'
	],
	#category : #SSDP
}

{ #category : #'instance creation' }
SSDPService class >> readFrom: aDatagram size: datagramSize [
	"Used by clients to parse the replies to discovery requests"
	^self new initializeFrom: aDatagram ofSize: datagramSize 
]

{ #category : #'instance creation' }
SSDPService class >> type: aServiceType location: aServiceLocation [
	"Used by server to initialize the service it offers"
	self notYetImplemented 
]

{ #category : #comparing }
SSDPService >> = anotherObject [
	self species = anotherObject species and: [ self uniqueServiceName = anotherObject uniqueServiceName ]
	
]

{ #category : #accessing }
SSDPService >> discoveryTime [
	^discoveryTime
]

{ #category : #comparing }
SSDPService >> hash [
	^self uniqueServiceName hash
]

{ #category : #'initialize - release' }
SSDPService >> initializeDiscovery: aDatagram ofSize: datagramSize [
	
	| response cacheParams |
	response := ZnResponse readFrom: aDatagram readStream.
	"If the response was not 200 OK, we are required to disregard it"
	response status = 200 ifFalse: [ ^nil ].
	notificationTypeSub := 'ssdp:discovery'.
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
	maxAge := ( $= split: (cacheParams detect: [:one | one beginsWith: 'max-age'] ifNone: '0')) last asNumber.
	


	
	
]

{ #category : #'initialize - release' }
SSDPService >> initializeNotify: aDatagram ofSize: datagramSize [
	
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
	discoveryTime := response headers at:'Date' ifAbsent: [ DateAndTime now].
	cacheParams := $, split: ((response headers at: 'Cache-control' ifAbsent: [''])) .
	"Could also be communicated through Expiry field, only support maxAge for now"
	maxAge := ( $= split: (cacheParams detect: [:one | one beginsWith: 'max-age'] ifNone: '0')) last asNumber asSeconds.


	
	
]

{ #category : #testing }
SSDPService >> isAvailabilityNotification [
	"header"
	^#('ssdp:alive' 'ssdp:discovery') includes: notificationTypeSub 
]

{ #category : #testing }
SSDPService >> isUnavailabilityNotification [
	
	^#'ssdp:byebye' = notificationTypeSub 
]

{ #category : #accessing }
SSDPService >> location [
	^location
]

{ #category : #accessing }
SSDPService >> maxAge [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^maxAge
]

{ #category : #accessing }
SSDPService >> serverInfo [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^serverInfo
]

{ #category : #accessing }
SSDPService >> serviceType [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^serviceType
]

{ #category : #accessing }
SSDPService >> uniqueServiceName [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^uniqueServiceName
]
