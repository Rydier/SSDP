"
An SSDPService is some resource avilable at a defined location.


"
Class {
	#name : #SSDPService,
	#superclass : #Object,
	#instVars : [
		'serviceType',
		'uniqueServiceName',
		'location',
		'serverInfo',
		'discoveryTime',
		'maxAge'
	],
	#category : #'SSDP-Core'
}

{ #category : #'instance creation' }
SSDPService class >> ofType: aServiceType atLocation: aServiceLocation [
	"Used by server to initialize the service it offers"

	^ self new initializeWithType: aServiceType at: aServiceLocation
]

{ #category : #comparing }
SSDPService >> = anotherObject [
	^self species = anotherObject species and: [ self uniqueServiceName = anotherObject uniqueServiceName ]
	
]

{ #category : #'server messages' }
SSDPService >> aliveResponseFor: aSocket [
	"The ping we send periodically to notify clients we are still here"
	"TODO: Rewrite to take multicastInfo as parameter "
	^('NOTIFY * HTTP/1.1
Host: ', (self remoteAddressString: aSocket) , ':' , aSocket remotePort asString, '
NT: ', serviceType ,'
NTS: ssdp:alive
USN: ', uniqueServiceName ,'
Location: ', location asString , '
Cache-Control: max-age = ', maxAge asSeconds printString,'

') withInternetLineEndings
]

{ #category : #'server messages' }
SSDPService >> byebyeResponseFor: aSocket [
	"The ping we send when shutting down to notify clients we can no longer provide services"
		"TODO: Rewrite to take multicastInfo as parameter "
	^('NOTIFY * HTTP/1.1
Host: ', (self remoteAddressString: aSocket), ':' , aSocket remotePort asString, ' 
NT: ', serviceType ,'
NTS: ssdp:byebye
USN: ', uniqueServiceName, '

') withInternetLineEndings
]

{ #category : #'accessing - cache validity' }
SSDPService >> cacheExpiry [ 
	^self discoveryTime + self maxAge asDuration
]

{ #category : #'server messages' }
SSDPService >> discoveryResponse [
	^('HTTP/1.1 200 OK
ST: ', serviceType ,'
USN: ',  uniqueServiceName,'
Location: ', location asString, '
Server: ', self serverInfo, '
Cache-Control: max-age = ', maxAge asSeconds printString,'

') withInternetLineEndings
	
]

{ #category : #'accessing - cache validity' }
SSDPService >> discoveryTime [
	^discoveryTime
]

{ #category : #comparing }
SSDPService >> hash [
	^self uniqueServiceName hash
]

{ #category : #'initialize - release' }
SSDPService >> initializeWithType: aServiceType at: aServiceLocation [
	| locationHash locationHex |
	serviceType := aServiceType.
	location := aServiceLocation asUrl.	"For current purposes, identify services uniquely by the hash of their location.
	Saves us a lot of trouble wrt. maintaining identity of services after restarts etc.
	(But of course means, if our services location changes, it is registed as a wholly new service)"
	locationHash := SHA256 new hashStream: aServiceLocation readStream.
	locationHex := locationHash hex readStream.
	uniqueServiceName := String
		streamContents: [ :stream | 
			stream
				nextPutAll: 'uuid:';
				nextPutAll: (locationHex next: 8);
				nextPut: $-;
				nextPutAll: (locationHex next: 4);
				nextPut: $-;
				nextPutAll: (locationHex next: 4);
				nextPut: $-;
				nextPutAll: (locationHex next: 4);
				nextPut: $-;
				nextPutAll: (locationHex next: 12);
				nextPutAll: '::';
				nextPutAll: aServiceType ].
	maxAge := 180 seconds
]

{ #category : #accessing }
SSDPService >> location [
	^location
]

{ #category : #testing }
SSDPService >> matchesType: aNotification [
	^ serviceType = 'ssdp:all'
		or: [ serviceType = aNotification serviceType ]
]

{ #category : #'accessing - cache validity' }
SSDPService >> maxAge [
	"The maximum amount of time since time of discovery this entry should be cached/relied upon"
	^maxAge
]

{ #category : #updating }
SSDPService >> merge: aNotification [
	uniqueServiceName
		ifNotNil:
			[ :usn | 
			usn = aNotification uniqueServiceName
				ifFalse: [ ^ self error: 'Cannot merge data from notification with different identity!' ] ].
	"Obligatory notification data"
	serviceType := aNotification serviceType.
	uniqueServiceName := aNotification uniqueServiceName.
	discoveryTime := aNotification discoveryTime.
	maxAge := aNotification maxAge.
	aNotification serverInfo ifNotNil: [ :info | serverInfo := info ].
	"Common SSDP fields"
	aNotification location ifNotNil: [ :loc | location := loc ]
]

{ #category : #printing }
SSDPService >> printOn: aStream [
	uniqueServiceName printOn: aStream
]

{ #category : #'private -printing' }
SSDPService >> remoteAddressString: aSocket [
	|addr|
	addr := aSocket remoteAddress.
	^addr size = 4 
		ifTrue: [ "IPv4"
			  (addr collect: #asString as: OrderedCollection) joinUsing: '.'  ] 
		ifFalse: [ "IPv6"
			 ((addr collect: [:e | e printStringBase: 16]) as: OrderedCollection) joinUsing: ':' ]
]

{ #category : #accessing }
SSDPService >> serverInfo [
	"Some identifier of the server on which service is running.
	uPnP 1.1 suggests:
	'OS/version Protocol/version Product/version"
	^serverInfo
]

{ #category : #accessing }
SSDPService >> serverInfo: someInfoString [
	^serverInfo := someInfoString
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

{ #category : #'accessing - cache validity' }
SSDPService >> validDuration [

	^self cacheExpiry - DateAndTime now.
]
