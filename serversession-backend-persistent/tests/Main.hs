module Main (main) where

import Control.Monad (forM_)
import Control.Monad.Logger (runStderrLoggingT, runNoLoggingT)
import Data.Pool (destroyAllResources)
import Database.Persist.Postgresql (createPostgresqlPool)
import Database.Persist.Sqlite (createSqlitePool)
import Test.Hspec
import Web.ServerSession.Backend.Persistent
import Web.ServerSession.Core.StorageTests

import qualified Control.Exception as E
import qualified Database.Persist.TH as P
import qualified Database.Persist.Sql as P

P.mkMigrate "migrateAll" serverSessionDefs

main :: IO ()
main = hspec $ parallel $
  forM_ [ ("PostgreSQL", createPostgresqlPool "host=localhost user=test dbname=test password=test" 20)
        , ("SQLite",     createSqlitePool "test.db" 1) ] $
    \(rdbms, createPool) ->
  describe ("SqlStorage on " ++ rdbms) $ do
    epool <-
      runIO $ E.try $ do
        pool <- runNoLoggingT createPool
        runStderrLoggingT $ P.runSqlPool (P.runMigration migrateAll) pool
        return pool
    case epool of
      Left (E.SomeException exc) ->
        it "failed to create connection or migrate database" $
          pendingWith (show exc)
      Right pool ->
        afterAll_ (destroyAllResources pool) $
          parallel $ allStorageTests (SqlStorage pool) it runIO shouldBe shouldReturn shouldThrow
