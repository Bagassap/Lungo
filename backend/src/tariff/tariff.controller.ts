import { Controller, Get, Put, Body, Query, Param, ParseFloatPipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { TariffService } from './tariff.service';
import { ZonaService, ZonaOjek } from './zona.service';

@ApiTags('Tariff')
@Controller('tariff')
export class TariffController {
  constructor(
    private readonly tariffService: TariffService,
    private readonly zonaService: ZonaService,
  ) {}

  @Get('calculate')
  @ApiOperation({ summary: 'Hitung tarif berdasarkan jarak (km)' })
  @ApiQuery({ name: 'distance', type: Number, example: 5.5 })
  calculate(@Query('distance', ParseFloatPipe) distance: number) {
    const fare = this.tariffService.calculate(distance);
    return { distanceKm: distance, fare };
  }

  @Get('info')
  @ApiOperation({ summary: 'Info struktur tarif' })
  getTariffInfo() {
    return this.tariffService.getTariffInfo();
  }

  @Get('estimate')
  @ApiOperation({ summary: 'Estimasi tarif zona GPS otomatis (Kemenhub)' })
  @ApiQuery({ name: 'lat', type: Number, example: -6.2088 })
  @ApiQuery({ name: 'lng', type: Number, example: 106.8456 })
  @ApiQuery({ name: 'km',  type: Number, example: 10 })
  estimateFare(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
    @Query('km',  ParseFloatPipe) km: number,
  ) {
    return this.zonaService.hitungTarif(km, lat, lng);
  }

  @Get('zones')
  @ApiOperation({ summary: 'Daftar semua zona tarif Kemenhub' })
  getAllZones() {
    return this.zonaService.semuaTarif();
  }

  @Put('zones/:zona')
  @ApiOperation({ summary: 'Update tarif per zona (in-memory, reset on restart)' })
  updateZone(
    @Param('zona') zona: string,
    @Body() body: { tarifPerKm?: number; tarifMinimalDriver?: number; feeLungo?: number },
  ) {
    const zonaKey = zona.toUpperCase() as ZonaOjek;
    if (!Object.values(ZonaOjek).includes(zonaKey)) {
      return { error: 'Zona tidak valid. Gunakan ZONA_I, ZONA_II, atau ZONA_III' };
    }
    return this.zonaService.updateTarif(zonaKey, body);
  }
}
