# SSDP
An [SSDP](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol) (Simple Service Discovery Protocol) implementation for Squeak/Pharo Smalltalk.
To load:
```smalltalk
Metacello new
	baseline: 'SSDP';
	repository: 'github://rydier/SSDP/repository';
	load.
```
Although SSDP is the underlying discovery protocol used by uPnP, it was never really fully standardized.
This implementation was based on http://quimby.gnus.org/internet-drafts/draft-cai-ssdp-v1-02.txt , minus the proxy functionality, which was dropped in a [later draft version](http://quimby.gnus.org/internet-drafts/draft-cai-ssdp-v1-03.txt). So in essence, the latest version of the draft is what is implemented. 
The later version contains much expanded sections on design rationales, which makes it a much better read for those who want to learn what a discovery protocol is all about and the tradeoffs involved, but with much less information density from the point of view of someone implementing the protocol.  

# Example usage
SSDP Server:
```smalltalk
|server|
server := SSDPServer v4SiteLocal.
server 
	offerServiceType: 'ssdp:testService'
	atLocation: 'http:/test.local/'.
server shutDown.
```
SSDP Client: 
```smalltalk
|client|
client := SSDPClient v4SiteLocal.
client filter: 'ssdp:all' 
	whenAvailable: [ :resource | 
		resource printOn: Transcript.
		'is available' printOn: Transcript.
		Transcript nextPut: Character cr. ]
	whenUnavailable: [ :resource | 
		resource printOn: Transcript.
		'is becoming unavailable' printOn: Transcript.
		Transcript nextPut: Character cr.  ].
```

More detailed documentation can be found in the class comments.
If you read the later draft, and discover something is not in accordance, please open an issue or send a pull request.
If you implement a better way of discovering available local interfaces (which is the worst part of the code as is) to start SSDP listeners on, I'd especially appreciate to be notified!

Migrated from http://smalltalkhub.com/#!/~henriksp/SSDP 
using https://github.com/peteruhnak/git-migration 
