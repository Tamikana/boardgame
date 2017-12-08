
- In haskell GameEndPoint map the service returns for plays
  to a constructor for the corresponding messages.

- Change haskell api to return score of a play.

- Compute real score in Haskell and return.

- intellij subscription by 12/14.

- Make sure dimension is odd.

- Very useful guide for styling:

    https://css-tricks.com/snippets/css/a-guide-to-flexbox/

- If the intellij play configuration goes awry and things like
  running tests stop working, the best remedy I have found is
  to simply create another empty play porject from inside intellij,
  get rid of its sources (keep build.sbt, poroject/, and yes target/
  as well), and copy your sources back to this project and merge your
  build.sbt taking care not to change configured stuff.

- TODO. Rule for ending the game is part of refactoring to use bag of letters
  without replacement.

- TODO. Matching algorithm needs to be based on the best guess as to 
  the real score of a play. 

## To Do

- TODO. Check cross words and add their score - what is the ruke for that?

- TODO. All validations.

- Intellij - add license header for file creation.
  Add license to recent new files.

- Check that rows.delete deletes everything.

- Do we have to close a db in slick?

- Add tests similar to the ones in the sample, then remove the sample.

## Known Issues

- No checks for crosswise words yet.

- For now user goes first. After starting a game, toss a coin in the client 
  to determine who goes first. If it is machine, do a machine play.

  Add center square image.

- Bug extending a word should constitute a legitimate play.

## Technical Debt

- API versioning - just include in URL.

- Document seeding and migration.

- PlaySpec has WsClient - how do you use it?

- Production config file has secret and must be read-only to 
  one trusted user.

- Re-enable and configure CSRF filter. See the application.conf for configuration.
  It is disabled there: play.filters.disabled+=play.filters.csrf.CSRFFilter

- Uniqueness of player name. Need an index for the database.

- Need to standardize errors. Including validation of request. Version 2.

- Removing abandoned games. Does it make sense to use Akka?

- Database migration. 

## Improvements

- Seeding should be part of migration.

  The program should know its own version. The database should know which
  version it is at. There is an ordered list of upgrade functions
  for each version. All we need is that the version numbers be ordered.
  Lexicographic order on the parts of the version.

  You run those upgrades that are for versions greater than the database
  and less than the program. If the data database is at a higher version
  should not run the program.

- More specific match tests and assertions. 

- Change the board to look like a scrabble board.

- Change the scoring to be consistent with scrabble.

- Change the probabilities to be consistent with scrabble.

- Connect to real dictionary.

- Document basic slick model of actions.

- Add play table.

- config db should give the default dev test and prod databases
  todo - later - best practices for config - reference vs application

- Parallel execution of tests. Later.

- What to do with fatal exception in a web server? 
  Need to research for later. For now let the framework handle it.
  Also if any regular exception escapes the Try just let the framework handle
  it for simplicity.

- Should the controller call on services asynchronously? 

- Linux dictionary:

    http://www.dict.org/bin/Dict - you can send a post request to this
      I guess you can start by just using this. 
      You can run your own server if the game becomes popular.
      Just view the source for this and use an http client to get it.

    http://www.dict.org/links.html

      Has links to client server software.

    http://www.informatik.uni-leipzig.de/~duc/Java/JDictd/
      provides an http server - it is old though 2004
    https://askubuntu.com/questions/650264/best-offline-dictionary-for-14-04-lts
    http://manpages.ubuntu.com/manpages/zesty/man8/dictd.8.html
    https://github.com/rocio/dictd/blob/master/src/test/java/com/dictionary/service/DictdTest.java

- Load balancing and monitoring crashes and restarting.

- Add real dictionary with meanings. There is a dictionary application built-in 
  to MAC. Is it on Linux? Should be able to get to it easily from Scala.

- Add bonus points and use the same tile values and Scrabble.

- Allow game to be resumed.

- Indexing.

- Provide levels in game.

- Implement sqlite file based access. May need a little experimentation.

      jdbc:sqlite:/home/me/my-db-file.sqlite
      val db = Database.forUrl("url",driver = "org.SQLite.Driver")

    slick.dbs.default.driver="slick.driver.SQLiteDriver$"
    slick.dbs.default.db.driver="org.sqlite.JDBC"
    slick.dbs.default.db.url="jdbc:sqlite:lite.db"
    slick.dbs.default.db.user="sa"
    slick.dbs.default.db.password=""
    slick.dbs.default.db.connectionInitSql="PRAGMA foreign_keys = ON"

    db {
        test {
            slick.driver = scala.slick.driver.SQLiteDriver
            driver = org.sqlite.JDBC
            url = "jdbc:sqlite::memory:?cache=shared"
           connectionPool = disabled
       }
    }

## Credits

Test Dictionary - http://www-personal.umich.edu/~jlawler/wordlist.html
compiled by John Lawler and put in the public domain with no restrictions
of use.
