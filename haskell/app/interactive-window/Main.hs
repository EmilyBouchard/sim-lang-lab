module Main (main) where

import Control.Exception (bracket, finally)
import Control.Monad (unless)
import Data.Char (isDigit)
import Data.Maybe (mapMaybe)
import Data.Word (Word64)
import Foreign.C.Types (CUInt)
import Options.Applicative
import Options.Applicative.Common (evalParser)
import SDL3 hiding (info, round)
import Text.Read (readMaybe)

data Action = Quit

data World = World {quitting :: Bool}
defaultWorld :: World
defaultWorld = World{quitting = False}

windowTitle :: String
windowTitle = "interactive-window"
windowWidth :: Int
windowWidth = 800
windowHeight :: Int
windowHeight = 600
windowFlags :: CUInt
windowFlags = 0

nsPerSecond :: Double
nsPerSecond = 1e9

nsToSeconds :: Word64 -> Double
nsToSeconds ns = fromIntegral ns / nsPerSecond

secondsToNs :: Double -> Word64
secondsToNs s = round (s * nsPerSecond)

sdlFail :: String -> IO a
sdlFail what = (\e -> fail (what <> ": " <> e)) =<< sdlGetError

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
  sdlInit [SDL_INIT_VIDEO] `orFail` "SDL_Init"
  withSDLWindowAndRenderer (\(_, renderer) -> run renderer) `finally` sdlQuit
  where
    orFail act what = act >>= \ok -> unless ok (sdlFail what)
    run renderer = do
      _ <- sdlSetRenderVSync renderer 1 -- 1: sync to every display refresh
      startTick <- sdlGetTicksNS
      loop renderer defaultWorld startTick
    loop renderer world ticksNS = do
      ticksNS' <- sdlGetTicksNS
      let dt = nsToSeconds $ ticksNS' - ticksNS
      world' <- step dt . foldl' apply world <$> drainActions
      unless (quitting world') $ do
        _ <- sdlSetRenderDrawColor renderer 0 0 0 255
        _ <- sdlRenderClear renderer
        _ <- sdlRenderPresent renderer
        loop renderer world' ticksNS'

{- basic implementation
drainEvents :: IO [SDLEvent]
drainEvents = do
  mev <- sdlPollEvent
  case mev of
    Nothing -> pure []
    Just ev -> (ev :) <$> drainEvents

  - could also be
  unfoldM sqlPollEvent
  - but requires dependency on monad-loops
-}

-- | Drain the SDL event queue, preserving arrival order
drainEvents :: IO [SDLEvent]
drainEvents = sdlPollEvent >>= maybe (pure []) (\ev -> (ev :) <$> drainEvents)

drainActions :: IO [Action]
drainActions = mapMaybe toAction <$> drainEvents

toAction :: SDLEvent -> Maybe Action
toAction (SDLEventQuit _) = Just Quit
toAction (SDLEventKeyboard k)
  | sdlKeyboardType k == SDL_EVENT_KEY_DOWN && sdlKeyboardKey k == SDLKEscape = Just Quit
toAction _ = Nothing

apply :: World -> Action -> World
apply w Quit = w{quitting = True}
apply w _ = w

step :: Double -> World -> World
step _ w = w
