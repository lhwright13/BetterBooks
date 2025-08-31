# the EchoWright platform's complete functionality goals

## User interaction features

- sleep timer
- chat notes generator.
  - should ask the user to describe what they want out of their notes. ie make notes about

## UI Pages

- Home
  - setting button
  - feed of new releases
  - sponsored books
  - recommended books
  - ads.
  - continue listening button
- Store
  - search
  - genres
  - All the usual stuff
- Player
    personas
    AI chat
    Book info
- profile button
  - shows all book listen to
  - connect with good reads
  - shows reveiws.
  - public and private bocks shown here.

## AI features

- the personas should be locked to one story, but the user can optionally add context from other book they are reading and other chats. This should use the pg vector on the backend if I am understanding that correctly. Lets make a plan for this and understand the cost of doing this for all users. Maybe this is a premium feature? This is highly relavent to learning.
- chat notes by chapter or by book
- chapter reveiws and Q&As for making sure that you got the right stuff out of the book. These could be fun honestly.
  - user understanding, build a user profile

## Example Usage of application

1. create account
    - sign in using google or apple account
    - add credit card for free trail or use app store subcription
    - verify email or whatever is the normal practice here
2. go to book store
    - you get 1-3 credits a month for books?
    - listen to prevues of the books
    - see list of personas and their background
    - reviews of the book
    - reviews of the personas
    - All other data the audible has
3. buy your book.
    - Would you like to download locally option
        - figure out how this works on the technical side:
            - what gets passed between the front the back end.
            - the users lib should be saved everywhere with their account. COPY audible here
    - The user should see the book in their lib now
4. user selects the book they want from their lib
5. goes to book play screen with the following options:
    - standard play pause skip +- 15 sec.
    - persona settings button
        - brings up this books personas page
        - on personas page we can
            - change the persona
            - clear the chat history
            - change cutomize the persona
            - create a new persona
    - voice chat button
        - pauses the book.
        - brings up a audio feedback graphic that moves as it hears you. detects when you are done talking. then responds back to you audible. These responses should be shorter and more conversational.
        - the book should then auto play once the reply is done.
    - text chat button
        - bring up a side page the shows a message chat style conversation.
        - voice chats queries should show up here as well
    - share button
        - should have all the options audable has
        - share review Here
    - audio setting button (optional)
        - ie bluetooth, settings etc.

## social side

- leave reviews of books and personas.
  - scan for dangerous reviews. how does this work?
- users can Follow other users.
- users can share personas. with eachother for different books
  - teachers and share and collect insides from users using their persona.

## persona creation

- from scratch
- off another base persona
- add relevant information history or focuses.

## teacher features

- Foreign language teachers will definitely want this, not sure about english teachers yet.
- insite collection from their personas (is this too invasive?)
  - mapped to exact questions
-

## data collection and insite generation

- what questions are people asking?
- where are they asking these questions
- what parts of the book are people loosing track of
- how does AI interaction effect user experience?
  - do they read more or put the book down?
- which personas are the most popular and which are actually helping people understand the book better?

## needs conversations (more for the business side)

- default persona plan
- how do you want to create a persona for your book?
  - as a teacher, pleasure reader, language teacher?
  - features: (basic and advanced mode)
    - document uploads
    - restrictions
    - voice
    - spoilers
    - edginess
    - other persona context
    - book contexts
  - UI Process:
    - dropdowns, txt box, colors, visuals
- pricing model
  - cost
  - free trail length
  - tiers Chat usage etc
  - affiliation codes for free book credits
- social media side of this,
  - good reads integration
  - reviews of books
  - reviews of personas
  - sharing your public and private personas
- is personas the right name?
- as a teacher how do you create a student profile?
  - stregths and weakness
  - etc.

## setting

### Personas

- auto restart after voice query or auto wait for another query
-

### account settings

- all the addable stuff
- account tiers

## Pitch Points

- Authentic intelligence no AI
  - each persona is thoughtfully built by teachers and authors to maximize your experience and your goal.
- I built this product because I want more people to read books.
- I want help every listener achieve their goal.
  - Every literature struggling with joyce or Shakespeare.
  - Every sci-fi nerd confused by countless alien worlds.
  - Every inspired traveler learning a new language through listening
- We can have a conversation about the data the we collect
  - this will be used with inform which books will do well and which wont. (big money here)

#### metrics that would sell

- reading comp scores
- reader retention
- what do publishers look at for this?
- audible conversion rate
- second book buy
- AI usage

# contacts

- nicky constantly
- ozy
- Philips exeter
- Ozys school
- Mcdonogh
- published from linked in
- 20 more audio book lovers

# people needed in this order

- Machine Learning Engineer, NOT SCIENTIST
- general backend developer
- Front end designer
- business manager
- sales lead
- cloud engineer
- DevOps person
- account and money manager for subscriptions
- PE/publisher and auther interaction manager.

#### TODO make table and add

- cost
- projected rev
- can I do it lvl
- role difficulty
- versitily

### Claude tips:
I run large software projects on Claude. I agree with most things that you say but I go deeper with the management of some things. I'll explain a bit of my system in case you can pick up anything from it.

So each project (is a Claude Project) has a written objective, some frameworks (rules we work to) and some project specific info. But in particular it has a number of AI "jobs" - typically 20 or more. The jobs are just like you would have in a traditional Dev world. I am doing one software project that I expect will take a year and I ultimately expect 100 or so AI jobs in it. I expect similar output that I would get from a 100 dev team in a fraction of my time.

The boss I call COO. He works with me to specify things and to keep the others in line. I have specialist jobs for things such as specification, testing, quality, database, front end, installations etc etc. You mentioned MCP. I have an MCP manager.

If I want to get a Job to do something substantial, I talk to the COO about it. He will spec it and set standards for completion quality. He will expect a report back. Once that activity is done to COO's satisfaction, another will be scheduled for that Job.

One thing that I believe could be of practical help to you is optimizing things around types of knowledge. This is important because you will generate a lot of knowledge and tokens have to be managed optimally. Think about the types of knowledge you need (and I give you some examples from my world):

Knowledge Shared across Projects (those frameworks I mentioned). These are in every Project Library.

Project knowledge that an AI job MUST know (what you are doing and why, project plan, the AI Jobs in the Project etc etc. These are in the Project Library.

Project Documents that an AI MIGHT need. These are in an index in 2) and the Job can access them on demand in the local file system via MCP.

Documents only of interest to the Job Type. These are stored locally per job type. In my world each job has its own folder and in this folder are identical subfolders

/context current.txt - Current state, priorities, decisions, issues
/history - Archived context files (timestamped)
/inbox - Messages/requests from other jobs - Format: YYYYMMDD_HHMM-[SenderJobID]-[Topic].txt
/outbox - Copies of sent messages - Format: YYYYMMDD_HHMM-to-[RecipientJobID]-[Topic].txt
/tech - Technical documentation specific to this job - Implementation details - Design documents - Working drafts
/control objectives.txt - Current job objectives and goals decisions.txt - Log of key decisions with rationale dependencies.txt- Dependencies on other jobs index.txt - Optional index of job's files/folders

You will see that jobs can "talk" to each other. How the Job maintains docs in here is dealt with in instructions in 2).

Once you start working like this you can do things to the highest standards and astonishingly rapidly. All docs to do with control are written by the COO.

One last thing. Each thread is initialized identically. "I want you to be COO (or whatever) in our project". At the end of the thread the job updates all its own knowledge files and maybe sends messages to COO or Doc Manager if there are wider issues. It then produces what we call a Park Document (about 10 pages of highly specified info about what happened in the thread). This Park document is for the Job Type and is Dated. Next time the same Job Type starts in a new thread it is instructed to read the previous Park doc for that type. That way continuity is maintained.

Good luck with everything.