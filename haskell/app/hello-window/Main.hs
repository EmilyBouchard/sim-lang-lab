{-# LANGUAGE BlockArguments #-}

module Main (main) where

import Control.Exception (bracket, finally)
import Control.Monad (unless)
import Data.Char (isDigit)
import Foreign.C.Types (CUInt)
import Options.Applicative

-- sdl3-hs exports a record field called `info` (SDLStorageInterface) that clashes with
-- optparse-applicative's `info`.
import SDL3 hiding (info)
import Text.Read (readMaybe)

windowTitle :: String
windowTitle = "hello-window"
windowWidth :: Int
windowWidth = 800
windowHeight :: Int
windowHeight = 600
windowFlags :: CUInt
windowFlags = 0

-- | A non-negative decimal integer. Plain 'read' would also accept hex (@0x10@) and surrounding
-- spaces, and would silently wrap around on overflow for 'Int'.
nonNegativeInt :: ReadM Int
nonNegativeInt = eitherReader \s -> case readMaybe s of
  Just n | all isDigit s, n <= toInteger (maxBound :: Int) -> Right (fromInteger n)
  _ -> Left ("expected a non-negative integer, got " <> show s)

-- | Optional @--frames N@ exits after N frames (used by the headless smoke test).
framesParser :: Parser (Maybe Int)
framesParser =
  optional
    ( option
        nonNegativeInt
        (long "frames" <> metavar "N" <> help "Exit after N frames")
    )

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
  -- On a bad command line execParser prints usage and the error, then exits non-zero, before
  -- SDL is initialised. --help prints the usage text and exits 0.
  maxFrames <-
    execParser $
      info
        (framesParser <**> helper)
        (fullDesc <> progDesc "Open an SDL3 window and clear it to a solid colour.")
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
