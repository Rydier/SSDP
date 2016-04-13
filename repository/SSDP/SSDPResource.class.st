"
An SSDPResource identifies a service point
"
Class {
	#name : #SSDPResource,
	#superclass : #Object,
	#instVars : [
		'location',
		'discoveryTime',
		'maxAge',
		'serviceType',
		'uniqueServiceName',
		'serverInfo'
	],
	#category : #SSDP
}

{ #category : #'instance creation' }
SSDPResource class >> readFrom: aDatagram size: datagramSize [
	^self new initializeFrom: aDatagram ofSize: datagramSize 
]

{ #category : #comparing }
SSDPResource >> = anotherObject [
	self species = anotherObject species and: [ self uniqueServiceName = anotherObject uniqueServiceName ]
	
]

{ #category : #accessing }
SSDPResource >> discoveryTime [
	^discoveryTime
]

{ #category : #comparing }
SSDPResource >> hash [
	^self uniqueServiceName hash
]

{ #category : #'initialize - release' }
SSDPResource >> initializeFrom: aDatagram ofSize: datagramSize [
	
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
	maxAge := ( $= split: (cacheParams detect: [:one | one beginsWith: 'max-age'] ifNone: '0')) last asNumber.


	
	
]

{ #category : #accessing }
SSDPResource >> location [
	^location
]

{ #category : #accessing }
SSDPResource >> maxAge [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^maxAge
]

{ #category : #accessing }
SSDPResource >> serverInfo [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^serverInfo
]

{ #category : #accessing }
SSDPResource >> serviceType [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^serviceType
]

{ #category : #accessing }
SSDPResource >> uniqueServiceName [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^uniqueServiceName
]
