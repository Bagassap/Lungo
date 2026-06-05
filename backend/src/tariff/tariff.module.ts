import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TariffService } from './tariff.service';
import { TariffController } from './tariff.controller';
import { ZonaService } from './zona.service';
import { TariffConfig } from './entities/tariff_config.entity';
import { TariffHistory } from './entities/tariff_history.entity';

@Module({
  imports: [TypeOrmModule.forFeature([TariffConfig, TariffHistory])],
  providers: [TariffService, ZonaService],
  controllers: [TariffController],
  exports: [TariffService, ZonaService],
})
export class TariffModule {}
