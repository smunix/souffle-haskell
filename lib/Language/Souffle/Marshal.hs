{-# OPTIONS_GHC -Wno-redundant-constraints #-}
{-# LANGUAGE FlexibleInstances, FlexibleContexts #-}
{-# LANGUAGE DefaultSignatures, TypeOperators #-}

-- | This module exposes a uniform interface to marshal values
--   to and from Souffle Datalog. This is done via the 'Marshal' typeclass.
--   Also, a mechanism is exposed for generically deriving marshalling
--   and unmarshalling code for simple product types.
module Language.Souffle.Marshal
  ( Marshal(..)
  , MonadPush(..)
  , MonadPop(..)
  ) where

import GHC.Generics
import Data.Int
import Data.Word
import qualified Data.Text as T
import qualified Data.Text.Short as TS
import qualified Data.Text.Lazy as TL
import qualified Language.Souffle.Internal.Constraints as C

{- | A typeclass for serializing primitive values from Haskell to Datalog.

This typeclass is only used internally and subject to change.

See also: 'MonadPop', 'Marshal'.
-}
class Monad m => MonadPush m where
  -- | Marshals a signed 32 bit integer to the datalog side.
  pushInt32 :: Int32 -> m ()
  -- | Marshals an unsigned 32 bit integer to the datalog side.
  pushUInt32 :: Word32 -> m ()
  -- | Marshals a float to the datalog side.
  pushFloat :: Float -> m ()
  -- | Marshals a string to the datalog side.
  pushString :: String -> m ()
  -- | Marshals a UTF8-encoded Text string to the datalog side.
  pushText :: TS.ShortText -> m ()
  -- | Marshals a UTF16-encoded Text string to the datalog side.
  pushTextUtf16 :: T.Text -> m ()

{- | A typeclass for serializing primitive values from Datalog to Haskell.

This typeclass is only used internally and subject to change.

See also: 'MonadPush', 'Marshal'.
-}
class Monad m => MonadPop m where
  -- | Unmarshals a signed 32 bit integer from the datalog side.
  popInt32 :: m Int32
  -- | Unmarshals an unsigned 32 bit integer from the datalog side.
  popUInt32 :: m Word32
  -- | Unmarshals a float from the datalog side.
  popFloat :: m Float
  -- | Unmarshals a string from the datalog side.
  popString :: m String
  -- | Unmarshals a Text string from the datalog side.
  popText :: m TS.ShortText
  -- | Unmarshals a UTF16-encoded Text string from the datalog side.
  popTextUtf16 :: m T.Text

{- | A typeclass for providing a uniform API to marshal/unmarshal values
     between Haskell and Souffle datalog.

The marshalling is done via a stack-based approach, where elements are
pushed/popped one by one. You need to make sure that the marshalling
of values happens in the correct order or unexpected things might happen
(including crashes). Pushing and popping of fields should happen in the
same order (from left to right, as defined in Datalog).

Generic implementations for 'push' and 'pop' that perform the previously
described behavior are available. This makes it possible to
write very succinct code:

@
data Edge = Edge String String deriving Generic

instance Marshal Edge
@
-}
class Marshal a where
  -- | Marshals a value to the datalog side.
  push :: MonadPush m => a -> m ()
  -- | Unmarshals a value from the datalog side.
  pop :: MonadPop m => m a

  default push
    :: (Generic a, C.SimpleProduct a, GMarshal (Rep a), MonadPush m)
    => a -> m ()
  default pop
    :: (Generic a, C.SimpleProduct a, GMarshal (Rep a), MonadPop m)
    => m a
  push a = gpush (from a)
  {-# INLINABLE push #-}
  pop = to <$> gpop
  {-# INLINABLE pop #-}

instance Marshal Int32 where
  push = pushInt32
  {-# INLINABLE push #-}
  pop = popInt32
  {-# INLINABLE pop #-}

instance Marshal Word32 where
  push = pushUInt32
  {-# INLINABLE push #-}
  pop = popUInt32
  {-# INLINABLE pop #-}

instance Marshal Float where
  push = pushFloat
  {-# INLINABLE push #-}
  pop = popFloat
  {-# INLINABLE pop #-}

instance Marshal String where
  push = pushString
  {-# INLINABLE push #-}
  pop = popString
  {-# INLINABLE pop #-}

instance Marshal TS.ShortText where
  push = pushText
  {-# INLINABLE push #-}
  pop = popText
  {-# INLINABLE pop #-}

instance Marshal T.Text where
  push = pushTextUtf16
  {-# INLINABLE push #-}
  pop = popTextUtf16
  {-# INLINABLE pop #-}

instance Marshal TL.Text where
  push = push . TL.toStrict
  {-# INLINABLE push #-}
  pop = TL.fromStrict <$> pop
  {-# INLINABLE pop #-}

class GMarshal f where
  gpush :: MonadPush m => f a -> m ()
  gpop  :: MonadPop m => m (f a)

instance Marshal a => GMarshal (K1 i a) where
  gpush (K1 x) = push x
  {-# INLINABLE gpush #-}
  gpop = K1 <$> pop
  {-# INLINABLE gpop #-}

instance (GMarshal f, GMarshal g) => GMarshal (f :*: g) where
  gpush (a :*: b) = do
    gpush a
    gpush b
  {-# INLINABLE gpush #-}
  gpop = (:*:) <$> gpop <*> gpop
  {-# INLINABLE gpop #-}

instance GMarshal a => GMarshal (M1 i c a) where
  gpush (M1 x) = gpush x
  {-# INLINABLE gpush #-}
  gpop = M1 <$> gpop
  {-# INLINABLE gpop #-}
