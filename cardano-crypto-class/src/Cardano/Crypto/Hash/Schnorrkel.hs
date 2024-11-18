{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE TypeFamilies #-}

-- | Implementation of the SCHNORKELL hashing algorithm.
module Cardano.Crypto.Hash.Schnorrkel
  ( SCHNORRKEL
  )
  where

import Cardano.Crypto.Hash.Class

data SCHNORRKEL

instance HashAlgorithm SCHNORRKEL where
  type SizeHash SCHNORRKEL = 20
  hashAlgorithmName _ = "SCHNORRKEL"
  digest _ = convert

convert :: ByteString -> ByteString
convert = id
