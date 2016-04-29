"
SSDPCache holds Services in an order sorted by their expiry time.
The two public methods are 
updateServiceFor: and removeService: , used to keep cache current with availability/unavailability notifications respectively.
"
Class {
	#name : #SSDPCache,
	#superclass : #LinkedList,
	#instVars : [
		'serviceType'
	],
	#category : #'SSDP-Client'
}

{ #category : #'as yet unclassified' }
SSDPCache class >> for: aServiceType [
	self new initializeType: aServiceType
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
SSDPCache >> removeService: aNotification [
	|currentLink|
	currentLink :=firstLink.
	(aNotification relatedTo: currentLink value) 
		ifTrue: [ firstLink := currentLink nextLink.
				firstLink ifNil: [ lastLink := nil ]]
		ifFalse: [|ourLink| 
			[ currentLink nextLink == nil or: 
				[aNotification relatedTo: currentLink nextLink value]] 
		   		whileFalse: [currentLink := currentLink nextLink].
			ourLink := currentLink nextLink.
			ourLink ifNotNil: [ currentLink nextLink: ourLink nextLink.
				ourLink == lastLink ifTrue: [ lastLink := currentLink] ].
			currentLink := ourLink. ].	

	^currentLink == nil ifFalse: [ currentLink value ]
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
				self addFirst: (ValueLink value: newService) ].

	currentLink value merge: aNotification.
	self updateServicePosition: currentLink.
	^ newService
]

{ #category : #private }
SSDPCache >> updateServicePosition: startLink [
	| currentLink actualService |
	currentLink := startLink.
	actualService := currentLink value.
	[ | nextLink |
	nextLink := currentLink nextLink.
	(nextLink notNil and: [ nextLink value cacheExpiry < actualService cacheExpiry ])
		whileFalse: [ currentLink value: nextLink value.
			nextLink value: actualService.
			currentLink := nextLink ] ]
]
