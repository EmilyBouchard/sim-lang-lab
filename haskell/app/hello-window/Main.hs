{-# LANGUAGE BlockArguments #-}

module Main (main) where

import Control.Exception (bracket, finally)
import Control.Monad (unless)
import Foreign.C.Types (CUInt)
import SDL3
import System.Environment (getArgs)

windowTitle :: String
windowTitle = "hello-window"
windowWidth :: Int
windowWidth = 800
windowHeight :: Int
windowHeight = 600
windowFlags :: CUInt
windowFlags = 0

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

createSDLWindowAndRenderer :: IO (SDLWindow, SDLRenderer)
createSDLWindowAndRenderer =
  maybe (sdlFail "SDL_CreateWindowAndRenderer") pure
    =<< sdlCreateWindowAndRenderer windowTitle windowWidth windowHeight windowFlags

withSDLWindowAndRenderer :: ((SDLWindow, SDLRenderer) -> IO a) -> IO a
withSDLWindowAndRenderer =
  bracket
    createSDLWindowAndRenderer
    (\(window, renderer) -> sdlDestroyRenderer renderer >> sdlDestroyWindow window)

main :: IO ()
main = do
  maxFrames <- parseFrames <$> getArgs
  sdlInit [SDL_INIT_VIDEO] `orFail` "SDL_Init"
  withSDLWindowAndRenderer (\(_, renderer) -> loop renderer maxFrames) `finally` sdlQuit
  where
    orFail act what = act >>= \ok -> unless ok (sdlFail what)
    loop renderer remaining = case remaining of
      Just 0 -> pure ()
      _ -> do
        quit <- quitRequested
        unless quit do
          _ <- sdlSetRenderDrawColor renderer 30 60 120 255
          _ <- sdlRenderClear renderer
          _ <- sdlRenderPresent renderer
          loop renderer (subtract 1 <$> remaining)
