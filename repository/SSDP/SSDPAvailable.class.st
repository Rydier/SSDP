"
This message  is sent by a server to the multicast address both when the server starts, to signal existing clients that a new service is available, and after that at intervals less than the maxAge of the service, so that clients won't signal interested parties that the service has become unavailable unneccessarily.
"
Class {
	#name : #SSDPAvailable,
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
SSDPAvailable class >> represents: aDatagram [
	"Available responses must always use the NOTIFY method"

	^ (aDatagram
		beginsWith: 'NOTIFY * HTTP/1.1')
		and:
			[|ntsIndex| "Hacky, potentially wrong if there's two fields of value ssdp:alive, but let's not do full header parsing twice..."
			(ntsIndex := aDatagram indexOfSubCollection: 'ssdp:alive') > 0 and: ["We reuse buffers, make sure we're not matching remnants of old datagram by checking against endofheaders sequence" ntsIndex < (aDatagram indexOfSubCollection: String crlf, String crlf) ]]	
]

{ #category : #conversion }
SSDPAvailable >> asService [
	^SSDPService new merge: self
]

{ #category : #handling }
SSDPAvailable >> deliver: service ifAvailable: whenAvailable ifUnavailable: whenByeBye [
	whenAvailable value: service
]

{ #category : #accessing }
SSDPAvailable >> discoveryTime [
	^discoveryTime
]

{ #category : #'initialize - release' }
SSDPAvailable >> initializeFrom: aDatagram [
| stream headers cacheParams |
	stream := aDatagram readStream.
	stream nextLine trim = 'NOTIFY * HTTP/1.1' ifFalse: [ ^nil ].
	headers := ZnHeaders readFrom: stream.
	(headers at: 'Nts') = 'ssdp:alive' ifFalse: [ ^nil ].
	"Obligatory SSDP notify fields"
	serviceType :=  headers at: 'Nt'.
	uniqueServiceName :=  headers at: 'Usn'.
	"Cache control fields"
	"TODO: Convert to DateAndTime if actually present"
	discoveryTime :=  headers at:'Date' ifAbsent: [ DateAndTime now].
	cacheParams := $, split: (( headers at: 'Cache-control' ifAbsent: [''])) .
	"Could also be communicated through Expiry field, only support maxAge for now"
	maxAge := ( $= split: (cacheParams detect: [:one | one beginsWith: 'max-age'] ifNone: '0')) last trim asNumber asSeconds.
	"Common SSDP notify fields"
	
	serverInfo :=  headers at: 'Server' ifAbsent: nil.
	location :=  (headers at: 'Location' ifAbsent: nil) ifNotNil: [:locString | locString asUrl].
	
]

{ #category : #accessing }
SSDPAvailable >> location [
	^location
]

{ #category : #accessing }
SSDPAvailable >> maxAge [
	^maxAge
]

{ #category : #accessing }
SSDPAvailable >> serverInfo [
	^serverInfo
]

{ #category : #handling }
SSDPAvailable >> serviceChangeIn: aCache [

	^aCache updateServiceFor: self
]
