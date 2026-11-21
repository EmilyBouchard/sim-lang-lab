{-# LANGUAGE BlockArguments #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Control.Monad (unless)
import SDL3
import System.Environment (getArgs)

-- | Optional @--frames N@ exits after N frames (used by the headless smoke test).
parseFrames :: [String] -> Maybe Int
parseFrames ("--frames" : n : _) = Just (read n)
parseFrames (_ : rest) = parseFrames rest
parseFrames [] = Nothing

sdlFail :: String -> IO a
sdlFail what = do
  err <- sdlGetError
  fail (what <> ": " <> err)

-- | Drain the event queue; True if a quit was requested (window close or Esc).
quitRequested :: IO Bool
quitRequested = go False
  where
    go acc = do
      mev <- sdlPollEvent
      case mev of
        Nothing -> pure acc
        Just ev -> go (acc || isQuit ev)
    isQuit (SDLEventQuit _) = True
    isQuit (SDLEventKeyboard k) = sdlKeyboardType k == SDL_EVENT_KEY_DOWN && sdlKeyboardKey k == SDLKEscape
    isQuit _ = False

main :: IO ()
main = do
  maxFrames <- parseFrames <$> getArgs
  ok <- sdlInit [SDL_INIT_VIDEO]
  unless ok (sdlFail "SDL_Init")
  bracket_ (pure ()) sdlQuit do
    created <- sdlCreateWindowAndRenderer "hello-window" 800 600 0
    (window, renderer) <- maybe (sdlFail "SDL_CreateWindowAndRenderer") pure created
    bracket (pure ()) (\_ -> sdlDestroyRenderer renderer >> sdlDestroyWindow window) \_ ->
      loop renderer maxFrames
  where
    loop renderer remaining = case remaining of
      Just 0 -> pure ()
      _ -> do
        quit <- quitRequested
        unless quit do
          _ <- sdlSetRenderDrawColor renderer 30 60 120 255
          _ <- sdlRenderClear renderer
          _ <- sdlRenderPresent renderer
          loop renderer (subtract 1 <$> remaining)
