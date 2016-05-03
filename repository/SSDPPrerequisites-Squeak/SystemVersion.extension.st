Extension { #name : #SystemVersion }

{ #category : #'*SSDPPrerequisites-Squeak' }
SystemVersion >> dottedMajorMinor [
	|ix| 
	ix := version  findFirst:  [:e | e isDigit].
	^ix = 0 ifTrue: [''] ifFalse: [version copyFrom: ix to: version size]
]

{ #category : #'*SSDPPrerequisites-Squeak' }
SystemVersion >> type [
	|ix| 
	ix := version  findFirst:  [:e | e isDigit].
	^ix = 0 ifTrue: [version] ifFalse: [version first: ix - 1]
]
