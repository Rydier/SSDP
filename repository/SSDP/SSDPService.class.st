"
An SSDPService is some resource avilable at a defined location; the three most important properties are:
- Service type: String : The type of service I offer.
- UniqueServiceName: String : An unique identifier of this particular service.
- Location : URL Where the service can be accessed. 

notificationSubtype/available really doesn't belong in the Service itself;  the class should be refactored into SSDPNotification classes (discovery / alive / byebye ) , which can then be used to update actual SSDPService's.

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
		'maxAge',
		'available',
		'notificationTypeSub'
	],
	#category : #'SSDP-Core'
}

{ #category : #'instance creation' }
SSDPService class >> type: aServiceType location: aServiceLocation [
	"Used by server to initialize the service it offers"
	self new initializeWithType: aServiceType at: aServiceLocation
]

{ #category : #comparing }
SSDPService >> = anotherObject [
	self species = anotherObject species and: [ self uniqueServiceName = anotherObject uniqueServiceName ]
	
]

{ #category : #'server messages' }
SSDPService >> aliveResponseFor: aSocket [
	"The ping we send periodically to notify clients we are still here"
	
	^('NOTIFY * HTTP/1.1
   Host: ', aSocket remoteAddress, ':' , aSocket remotePort, ' 
   NT: ', serviceType ,'
   NTS: ssdp:alive
   USN: ', uniqueServiceName ,'
   Cache-Control: max-age = ', maxAge asSeconds printString,'
') withInternetLineEndings
]

{ #category : #'server messages' }
SSDPService >> byebyeResponseFor: aSocket [
	"The ping we send when shutting down to notify clients we can no longer provide services"
	
	^('NOTIFY * HTTP/1.1
   Host: ', aSocket remoteAddress, ':' , aSocket remotePort, ' 
   NT: ', serviceType ,'
   NTS: ssdp:byebye
   USN: ', uniqueServiceName, '
') withInternetLineEndings
]

{ #category : #accessing }
SSDPService >> cacheExpiry [ 
	^self discoveryTime + self maxAge asDuration
]

{ #category : #'server messages' }
SSDPService >> discoveryResponse [
	^('HTTP/1.1 200 OK
   ST: ', serviceType ,'
   USN: ', serviceType , ':' , self uuid,'
	Server: ', self serviceLocation, '
	Cache-Control: max-age = ', maxAge asSecond printString,'
	') withInternetLineEndings
	
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
SSDPService >> initializeWithType: aServiceType at: aServiceLocation [
	"For current purposes, identify services uniquely by the hash of their location.
	Saves us a lot of trouble wrt. maintaining identity of services after restarts etc.
	(But of course means, if our services location changes, it is registed as a wholly new service)"
	|locationHash|
	serviceType := aServiceType.
	location := aServiceLocation asUrl.
	locationHash := (SHA256 new hashStream: aServiceLocation readStream) first: 16.
	uniqueServiceName := 'uuid:', locationHash hex asLowercase, ':', aServiceLocation 
	
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
