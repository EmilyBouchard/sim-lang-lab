{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Control.Monad (unless)
import Foreign.C.ConstPtr (ConstPtr (..))
import Foreign.C.String (peekCString, withCString)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr)
import Foreign.Storable (peek)
import SDL3.Sys qualified as SDL
import SDL3.Sys.Bindgen.Events (SDL_Event)
import System.Environment (getArgs)

-- | Optional @--frames N@ exits after N frames (used by the headless smoke test).
parseFrames :: [String] -> Maybe Int
parseFrames ("--frames" : n : _) = Just (read n)
parseFrames (_ : rest) = parseFrames rest
parseFrames [] = Nothing

sdlFail :: String -> IO a
sdlFail what = do
  err <- peekCString . unConstPtr =<< SDL.getError
  fail (what <> ": " <> err)

-- | Drain the event queue; True if a quit was requested (window close or Esc).
quitRequested :: IO Bool
quitRequested = alloca \evPtr -> go evPtr False
  where
    go :: Ptr SDL_Event -> Bool -> IO Bool
    go evPtr acc = do
      got <- SDL.pollEvent evPtr
      if not got
        then pure acc
        else do
          ev <- peek evPtr
          let isQuit = ev.type' == 0x100 -- SDL_EVENT_QUIT
              isEsc = ev.type' == 0x300 && ev.key.key == 27 -- KEY_DOWN, SDLK_ESCAPE
          go evPtr (acc || isQuit || isEsc)

main :: IO ()
main = do
  maxFrames <- parseFrames <$> getArgs
  ok <- SDL.init SDL.SDL_INIT_VIDEO
  unless ok (sdlFail "SDL_Init")
  bracket_ (pure ()) SDL.quit do
    alloca \winPtr -> alloca \rendPtr -> do
      created <- withCString "hello-window" \t ->
        SDL.createWindowAndRenderer (ConstPtr t) 800 600 0 winPtr rendPtr
      unless created (sdlFail "SDL_CreateWindowAndRenderer")
      window <- peek winPtr
      renderer <- peek rendPtr
      bracket (pure ()) (\_ -> SDL.destroyRenderer renderer >> SDL.destroyWindow window) \_ ->
        loop renderer maxFrames
  where
    loop renderer remaining = case remaining of
      Just 0 -> pure ()
      _ -> do
        quit <- quitRequested
        unless quit do
          _ <- SDL.setRenderDrawColor renderer 30 60 120 255
          _ <- SDL.renderClear renderer
          _ <- SDL.renderPresent renderer
          loop renderer (subtract 1 <$> remaining)
