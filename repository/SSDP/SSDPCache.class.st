"
SSDPCache holds Services ordered by expiry time, so the next expiring service can always be queried using #first.

updateServiceFor: and removeServiceFor:  constitute the public API used to keep cache current with availability/unavailability notifications, while removeService: is used for timing-based expiry. 



"
Class {
	#name : #SSDPCache,
	#superclass : #LinkedList,
	#instVars : [
		'serviceType',
		'accessMutex',
		'entrySemaphore'
	],
	#category : #'SSDP-Client'
}

{ #category : #'as yet unclassified' }
SSDPCache class >> for: aServiceType [
	^self new initializeType: aServiceType
]

{ #category : #accessing }
SSDPCache >> first [
	"This method blocks until an entry is available"
	entrySemaphore wait.
	^[super first] ensure: [entrySemaphore signal ]
]

{ #category : #'initialize - release' }
SSDPCache >> initialize [
	"EntrySemaphore excessSignals is a counter of current items in the cache, used to block on #first sends until entries are available."
	entrySemaphore := Semaphore new.
	"Since both discovery and automatic expulsion processes can end up removing services, we protect add and remove operations by this mutex."
	accessMutex := Mutex new.
]

{ #category : #'initialize - release' }
SSDPCache >> initializeType: aType [
	serviceType := aType
]

{ #category : #private }
SSDPCache >> linkOfServiceRelatedTo: aNotification ifAbsent: errorBlock [
	"Find the link containing service with same uniqueServiceName"
		| aLink |
	aLink := firstLink.
	[aLink == nil ] whileFalse:
		[(aNotification relatedTo: aLink value) ifTrue: [ ^aLink ].
		aLink := aLink nextLink].
	^errorBlock value
]

{ #category : #private }
SSDPCache >> matchesType: aNotification [
	^ serviceType = 'ssdp:all'
		or: [ serviceType = aNotification serviceType ]
]

{ #category : #accessing }
SSDPCache >> removeService: aService [
	"Used to prune inactive processes from cache"

	^ accessMutex
		critical: [ 
			(self remove: aService ifAbsent: [ nil ])
				ifNotNil: [ :removedService | 
					entrySemaphore wait.
					removedService ] ]
]

{ #category : #accessing }
SSDPCache >> removeServiceFor: aNotification [
	"Used to remove services we are being told explicitly will no longer be available"
	| currentLink |
	accessMutex
		critical:
			[ currentLink := firstLink.
			firstLink ifNil: [^nil ].
			(aNotification relatedTo: currentLink value)
				ifTrue: [ entrySemaphore wait.
					firstLink := currentLink nextLink.
					 ]
				ifFalse:
					[ | ourLink |
					[ currentLink nextLink == nil
						or: [ aNotification relatedTo: currentLink nextLink value ] ]
						whileFalse: [ currentLink := currentLink nextLink ].
					ourLink := currentLink nextLink.
					ourLink
						ifNotNil:
							[ entrySemaphore wait.
							currentLink nextLink: ourLink nextLink.
							ourLink == lastLink
								ifTrue: [ lastLink := currentLink ] ].
					currentLink := ourLink ] ].
	^ currentLink == nil
		ifFalse: [ currentLink value ]
]

{ #category : #accessing }
SSDPCache >> serviceType [
	^serviceType
]

{ #category : #accessing }
SSDPCache >> updateServiceFor: aNotification [
	"Check matching type, and if absent, add and return new service then add if absent, or move according to updated timeout value"
	| currentLink newService|
	(self matchesType: aNotification)
		ifFalse: [ ^ nil ].
	currentLink := self
		linkOfServiceRelatedTo: aNotification
		ifAbsent: [ newService := aNotification asService.
				[self addFirst: (ValueLink value: newService)] ensure: [ 
				entrySemaphore signal]
				 ].
	accessMutex
		critical:
			[ 
	currentLink value merge: aNotification.
	self updateServicePosition: currentLink].
	^ newService
]

{ #category : #private }
SSDPCache >> updateServicePosition: startLink [
	| currentLink actualService nextLink|
	"Move startLink to new location in cache, after its cacheExpiry has been increased"
	currentLink := startLink.
	actualService := currentLink value.
	[
	nextLink := currentLink nextLink.
	(nextLink notNil and: [ nextLink value cacheExpiry < actualService cacheExpiry ])]
		whileTrue: [ currentLink value: nextLink value.
			nextLink value: actualService.
			currentLink := nextLink ] 
]
