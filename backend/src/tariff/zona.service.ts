import { Injectable } from '@nestjs/common';

export enum ZonaOjek {
  ZONA_I = 'ZONA_I',
  ZONA_II = 'ZONA_II',
  ZONA_III = 'ZONA_III',
}

export interface TarifZona {
  zona: ZonaOjek;
  namaZona: string;
  wilayah: string;
  tarifPerKm: number;
  tarifMinimalDriver: number;
  feeLungo: number;
  thresholdKm: number;
}

@Injectable()
export class ZonaService {

  private readonly TARIF: Record<ZonaOjek, TarifZona> = {
    [ZonaOjek.ZONA_II]: {
      zona: ZonaOjek.ZONA_II,
      namaZona: 'Zona II',
      wilayah: 'Jabodetabek',
      tarifPerKm: 2650,
      tarifMinimalDriver: 14000,
      feeLungo: 500,
      thresholdKm: Math.round(14000 / 2650 * 10) / 10,
    },
    [ZonaOjek.ZONA_I]: {
      zona: ZonaOjek.ZONA_I,
      namaZona: 'Zona I',
      wilayah: 'Sumatera, Jawa non-Jabodetabek, Bali',
      tarifPerKm: 2075,
      tarifMinimalDriver: 14000,
      feeLungo: 500,
      thresholdKm: Math.round(14000 / 2075 * 10) / 10,
    },
    [ZonaOjek.ZONA_III]: {
      zona: ZonaOjek.ZONA_III,
      namaZona: 'Zona III',
      wilayah: 'Kalimantan, Sulawesi, NTT, NTB, Maluku, Papua',
      tarifPerKm: 2350,
      tarifMinimalDriver: 14000,
      feeLungo: 500,
      thresholdKm: Math.round(14000 / 2350 * 10) / 10,
    },
  };

  private readonly JABODETABEK = {
    latMin: -6.9, latMax: -5.9,
    lngMin: 106.4, lngMax: 107.2,
  };

  private readonly ZONA_III_PROVINSI = [
    { name: 'Kalimantan Barat',   latMin: -4.0, latMax: 2.5,  lngMin: 108.0, lngMax: 114.8 },
    { name: 'Kalimantan Tengah',  latMin: -4.5, latMax: 0.0,  lngMin: 110.0, lngMax: 116.0 },
    { name: 'Kalimantan Selatan', latMin: -4.5, latMax: -1.0, lngMin: 114.0, lngMax: 117.5 },
    { name: 'Kalimantan Timur',   latMin: -2.5, latMax: 2.5,  lngMin: 114.5, lngMax: 119.0 },
    { name: 'Kalimantan Utara',   latMin: 1.0,  latMax: 4.5,  lngMin: 114.5, lngMax: 118.0 },
    { name: 'Sulawesi Utara',     latMin: 0.0,  latMax: 4.0,  lngMin: 122.0, lngMax: 127.0 },
    { name: 'Sulawesi Tengah',    latMin: -3.5, latMax: 1.5,  lngMin: 119.5, lngMax: 124.5 },
    { name: 'Sulawesi Selatan',   latMin: -6.0, latMax: -1.5, lngMin: 119.0, lngMax: 121.5 },
    { name: 'Sulawesi Tenggara',  latMin: -5.5, latMax: -2.5, lngMin: 120.5, lngMax: 124.5 },
    { name: 'Sulawesi Barat',     latMin: -3.5, latMax: -0.5, lngMin: 118.5, lngMax: 120.0 },
    { name: 'Gorontalo',          latMin: -0.5, latMax: 1.0,  lngMin: 121.5, lngMax: 123.5 },
    { name: 'Maluku',             latMin: -8.5, latMax: -1.5, lngMin: 124.0, lngMax: 132.0 },
    { name: 'Maluku Utara',       latMin: -2.0, latMax: 3.5,  lngMin: 125.0, lngMax: 129.5 },
    { name: 'NTT',                latMin: -11.0, latMax: -8.0, lngMin: 118.0, lngMax: 125.5 },
    { name: 'Papua Barat',        latMin: -4.5, latMax: 0.5,  lngMin: 130.0, lngMax: 136.5 },
    { name: 'Papua',              latMin: -9.5, latMax: -1.0, lngMin: 135.0, lngMax: 141.0 },
  ];

  detectZona(lat: number, lng: number): ZonaOjek {
    if (
      lat >= this.JABODETABEK.latMin &&
      lat <= this.JABODETABEK.latMax &&
      lng >= this.JABODETABEK.lngMin &&
      lng <= this.JABODETABEK.lngMax
    ) {
      return ZonaOjek.ZONA_II;
    }

    for (const prov of this.ZONA_III_PROVINSI) {
      if (
        lat >= prov.latMin && lat <= prov.latMax &&
        lng >= prov.lngMin && lng <= prov.lngMax
      ) {
        return ZonaOjek.ZONA_III;
      }
    }

    return ZonaOjek.ZONA_I;
  }

  getTarif(zona: ZonaOjek): TarifZona {
    return this.TARIF[zona];
  }

  updateTarif(zona: ZonaOjek, updates: Partial<Pick<TarifZona, 'tarifPerKm' | 'tarifMinimalDriver' | 'feeLungo'>>): TarifZona {
    const current = this.TARIF[zona];
    if (updates.tarifPerKm !== undefined)       current.tarifPerKm = updates.tarifPerKm;
    if (updates.tarifMinimalDriver !== undefined) {
      current.tarifMinimalDriver = updates.tarifMinimalDriver;
      current.thresholdKm = Math.round(current.tarifMinimalDriver / current.tarifPerKm * 10) / 10;
    }
    if (updates.feeLungo !== undefined)          current.feeLungo = updates.feeLungo;
    current.thresholdKm = Math.round(current.tarifMinimalDriver / current.tarifPerKm * 10) / 10;
    return current;
  }

  hitungTarif(distanceKm: number, lat: number, lng: number): {
    zona: ZonaOjek;
    namaZona: string;
    fareDriver: number;
    farePassenger: number;
    feeLungo: number;
    distanceKm: number;
    tarifPerKm: number;
  } {
    const zona  = this.detectZona(lat, lng);
    const tarif = this.getTarif(zona);
    const km    = Math.max(distanceKm, 0);

    let fareDriver: number;
    if (km <= tarif.thresholdKm) {
      fareDriver = tarif.tarifMinimalDriver;
    } else {
      fareDriver = Math.round(
        tarif.tarifMinimalDriver + (km - tarif.thresholdKm) * tarif.tarifPerKm,
      );
    }

    const feeLungo      = tarif.feeLungo;
    const farePassenger = fareDriver + feeLungo;

    return { zona, namaZona: tarif.namaZona, fareDriver, farePassenger, feeLungo, distanceKm: km, tarifPerKm: tarif.tarifPerKm };
  }

  semuaTarif(): TarifZona[] {
    return Object.values(this.TARIF);
  }
}
