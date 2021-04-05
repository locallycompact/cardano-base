{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RankNTypes #-}

module Cardano.Slotting.EpochInfo.API
  ( EpochInfo (..),
    epochInfoSize,
    epochInfoFirst,
    epochInfoEpoch,
    epochInfoRange,
    epochInfoSlotToRelativeTime,
    epochInfoSlotToUTCTime,

    -- * Utility
    hoistEpochInfo,
    generalizeEpochInfo,
  )
where

import Cardano.Slotting.Slot (EpochNo (..), EpochSize (..), SlotNo (..))
import Cardano.Slotting.Time (RelativeTime, SystemStart, fromRelativeTime)
import Control.Monad.Morph (generalize)
import Data.Functor.Classes (showsUnaryWith)
import Data.Functor.Identity
import Data.Time.Clock (UTCTime)
import GHC.Stack (HasCallStack)
import NoThunks.Class (NoThunks, OnlyCheckWhnfNamed (..))

-- | Information about epochs
--
-- Epochs may have different sizes at different times during the lifetime of the
-- blockchain. This information is encapsulated by 'EpochInfo'; it is
-- parameterized over a monad @m@ because the information about how long each
-- epoch is may depend on information derived from the blockchain itself, and
-- hence requires access to state.
--
-- The other functions provide some derived information from epoch sizes. In the
-- default implementation all of these functions query and update an internal
-- cache maintaining cumulative epoch sizes; for that reason, all of these
-- functions live in a monad @m@.
data EpochInfo m
  = EpochInfo
      { -- | Return the size of the given epoch as a number of slots
        --
        -- Note that the number of slots does /not/ bound the number of blocks,
        -- since the EBB and a regular block share a slot number.
        epochInfoSize_ :: HasCallStack => EpochNo -> m EpochSize,
        -- | First slot in the specified epoch
        --
        -- See also 'epochInfoRange'
        epochInfoFirst_ :: HasCallStack => EpochNo -> m SlotNo,
        -- | Epoch containing the given slot
        --
        -- We should have the property that
        --
        -- > s `inRange` epochInfoRange (epochInfoEpoch s)
        epochInfoEpoch_ :: HasCallStack => SlotNo -> m EpochNo,
        -- | The 'RelativeTime' of the start of the given slot
        --
        -- This calculation depends on the varying slot lengths of the relevant
        -- epochs.
        --
        -- See also 'epochInfoSlotToUTCTime'.
        epochInfoSlotToRelativeTime_ ::
          HasCallStack => SlotNo -> m RelativeTime
      }
  deriving NoThunks via OnlyCheckWhnfNamed "EpochInfo" (EpochInfo m)

-- | Show instance only for non-stateful instances
instance Show (EpochInfo Identity) where
  showsPrec p ei =
    showsUnaryWith showsPrec "fixedSizeEpochInfo" p
      $ runIdentity
      $ epochInfoSize ei (EpochNo 0)

epochInfoRange :: Monad m => EpochInfo m -> EpochNo -> m (SlotNo, SlotNo)
epochInfoRange epochInfo epochNo =
  aux <$> epochInfoFirst epochInfo epochNo
    <*> epochInfoSize epochInfo epochNo
  where
    aux :: SlotNo -> EpochSize -> (SlotNo, SlotNo)
    aux (SlotNo s) (EpochSize sz) = (SlotNo s, SlotNo (s + sz - 1))

-- | The start of the given slot
epochInfoSlotToUTCTime ::
     (HasCallStack, Monad m)
  => EpochInfo m
  -> SystemStart
  -> SlotNo
  -> m UTCTime
epochInfoSlotToUTCTime ei start sl =
  fromRelativeTime start <$> epochInfoSlotToRelativeTime ei sl

{-------------------------------------------------------------------------------
  Extraction functions that preserve the HasCallStack constraint

  (Ideally, ghc would just do this..)
-------------------------------------------------------------------------------}

epochInfoSize :: HasCallStack => EpochInfo m -> EpochNo -> m EpochSize
epochInfoSize = epochInfoSize_

epochInfoFirst :: HasCallStack => EpochInfo m -> EpochNo -> m SlotNo
epochInfoFirst = epochInfoFirst_

epochInfoEpoch :: HasCallStack => EpochInfo m -> SlotNo -> m EpochNo
epochInfoEpoch = epochInfoEpoch_

epochInfoSlotToRelativeTime ::
  HasCallStack => EpochInfo m -> SlotNo -> m RelativeTime
epochInfoSlotToRelativeTime = epochInfoSlotToRelativeTime_

{-------------------------------------------------------------------------------
  Utility
-------------------------------------------------------------------------------}

hoistEpochInfo :: (forall a. m a -> n a) -> EpochInfo m -> EpochInfo n
hoistEpochInfo f ei = EpochInfo
  { epochInfoSize_ = f . epochInfoSize ei,
    epochInfoFirst_ = f . epochInfoFirst ei,
    epochInfoEpoch_ = f . epochInfoEpoch ei,
    epochInfoSlotToRelativeTime_ = f . epochInfoSlotToRelativeTime ei
  }

generalizeEpochInfo :: Monad m => EpochInfo Identity -> EpochInfo m
generalizeEpochInfo = hoistEpochInfo generalize
