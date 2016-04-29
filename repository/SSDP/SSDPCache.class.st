"
SSDPCache holds Services in an order sorted by their expiry time.
The two public methods are 
updatePositionOfService: and removeService: , used for availability/unavailability notifications respectively.
"
Class {
	#name : #SSDPCache,
	#superclass : #LinkedList,
	#instVars : [
		'serviceType'
	],
	#category : #SSDP
}

{ #category : #'as yet unclassified' }
SSDPCache class >> for: aServiceType [
	self new initializeType: aServiceType
]

{ #category : #'initialize - release' }
SSDPCache >> initializeType: aType [
	serviceType := aType
]

{ #category : #accessing }
SSDPCache >> linkOfService: aService ifAbsent: errorBlock [
	"Find the link containing service with same uniqueServiceName"
		| aLink |
	aLink := firstLink.
	[aLink == nil ] whileFalse:
		[aLink value = aService ifTrue: [ ^aLink ].
		aLink := aLink nextLink].
	^errorBlock value
]

{ #category : #accessing }
SSDPCache >> matchesType: aService [
	^ serviceType = 'ssdp:all'
		or: [ serviceType = aService serviceType ]
]

{ #category : #accessing }
SSDPCache >> removeService: aService [
	|currentLink|
	currentLink :=firstLink.
	currentLink value  = aService  
		ifTrue: [ firstLink  := currentLink nextLink.
				firstLink ifNil: [ lastLink := nil ]]
		ifFalse: [|ourLink| 
			[ currentLink nextLink == nil or: 
				[currentLink nextLink value  = aService ]] 
		   		whileFalse: [currentLink := currentLink nextLink].
			ourLink := currentLink nextLink.
			ourLink ifNotNil: [ currentLink nextLink: ourLink nextLink.
				ourLink == lastLink ifTrue: [ lastLink := currentLink] ].
			currentLink := ourLink. ].
					

	^currentLink == nil ifTrue: [ nil] ifFalse: [ currentLink value ]
]

{ #category : #accessing }
SSDPCache >> updatePositionOfService: aService [
	| currentLink nextLink actualService |
	(self matchesType: aService)
		ifFalse: [ ^ nil ].
	currentLink := self
		linkOfService: aService
		ifAbsent: [ self addFirst: (Link new value: aService) ].
	actualService := currentLink value.
	actualService updateCacheExpiryFrom: aService.
	[ nextLink := currentLink nextLink.
	(nextLink notNil
		and:
			[ nextLink value cacheExpiry
				< actualService cacheExpiry ])
		whileFalse:
			[ currentLink value: nextLink value.
			nextLink value: actualService.
			currentLink := nextLink ] ].
	^ currentLink
]
