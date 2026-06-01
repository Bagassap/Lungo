import { Controller, Get, Query, ParseFloatPipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { TariffService } from './tariff.service';

@ApiTags('Tariff')
@Controller('tariff')
export class TariffController {
  constructor(private readonly tariffService: TariffService) {}

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
}
