#!/usr/bin/env bash
# Sondagem temporária do bucket público do Open-Meteo (AWS Open Data, sem conta)
set -u
aws s3 ls --no-sign-request s3://openmeteo/data/ | head -60
for m in copernicus_era5_land copernicus_era5; do
  echo "== $m"; aws s3 ls --no-sign-request s3://openmeteo/data/$m/ | head -40
  aws s3 ls --no-sign-request s3://openmeteo/data/$m/temperature_2m/ | head -20
  aws s3 ls --no-sign-request s3://openmeteo/data/$m/temperature_2m/ | tail -5
  aws s3 ls --no-sign-request s3://openmeteo/data/$m/temperature_2m_max/ | head -5
  aws s3 ls --no-sign-request s3://openmeteo/data/$m/static/ 2>/dev/null | head
done
aws s3 ls --no-sign-request s3://openmeteo/data/copernicus_era5_land/ --recursive --summarize 2>/dev/null | tail -3
