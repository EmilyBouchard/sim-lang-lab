module Main (main) where

import Control.Exception (bracket, finally)
import Control.Monad (unless)
import Data.Maybe (mapMaybe)
import Data.Word (Word64)
import Foreign.C.Types (CUInt)
import SDL3 hiding (cos, info, round, sin)

tail' :: [a] -> [a]
tail' = drop 1

type Point = (Double, Double)

data Action = Quit

data World = World {quitting :: Bool}
defaultWorld :: World
defaultWorld = World{quitting = False}

uv0 :: SDLFPoint
uv0 = SDLFPoint 0 0

pointToVertex :: Point -> SDLFColor -> SDLFPoint -> SDLVertex
pointToVertex (x, y) = SDLVertex (SDLFPoint (realToFrac x) (realToFrac y))

pointsToVertices :: [Point] -> SDLFColor -> [SDLVertex]
pointsToVertices xs c = map (\x -> pointToVertex x c uv0) xs

circleTriangles :: Point -> Double -> [Point]
circleTriangles (x, y) r = concatMap (\(p1, p2) -> [p1, p2, (x, y)]) rim
  where
    steps :: Int
    steps = 32
    angleStep = pi * 2 / fromIntegral steps
    pointN n = (x + r * cos (fromIntegral n * angleStep), y + r * sin (fromIntegral n * angleStep))
    rim = let xs = [pointN v | v <- [0 .. steps]] in zip xs (tail' xs)

trianglePoints :: Point -> Double -> [Point]
trianglePoints (x, y) r = [pointA . angleN $ n | n <- [0 .. 3]]
  where
    angleN n = 3 * pi / 2 + n * (2 * pi / 3)
    pointA a = (x + r * cos a, y + r * sin a)

circleColor :: SDLFColor
circleColor = SDLFColor 0 0 1 1

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
        _ <- sdlSetRenderDrawColor renderer 45 45 45 255 -- dark background
        _ <- sdlRenderClear renderer
        _ <- sdlRenderGeometry renderer Nothing (pointsToVertices circle circleColor) Nothing
        _ <- sdlSetRenderDrawColor renderer 0 255 0 255 -- green square
        _ <- sdlRenderFillRect renderer (Just $ SDLFRect 100 100 100 100)
        _ <- sdlSetRenderDrawColor renderer 255 0 0 255 -- red triangle
        _ <- sdlRenderLines renderer triangle
        _ <- sdlRenderPresent renderer
        loop renderer world' ticksNS'
      where
        circle = circleTriangles (400, 300) 50
        triangle = map (\(x, y) -> SDLFPoint (realToFrac x) (realToFrac y)) $ trianglePoints (400, 300) 30

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
