Extension { #name : #SequenceableCollection }

{ #category : #'*SSDPPrerequisites-Squeak' }
SequenceableCollection >> splitOn: anObject [
	| splitter |
	splitter := anObject isCollection ifTrue: [anObject] ifFalse: [Array with: anObject].
	^self splitBy: splitter
]
