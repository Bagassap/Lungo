import { Test, TestingModule } from '@nestjs/testing';
import { TariffController } from './tariff.controller';
import { TariffService } from './tariff.service';

describe('TariffController', () => {
  let controller: TariffController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [TariffController],
      providers: [
        {
          provide: TariffService,
          useValue: {
            calculate: jest.fn().mockReturnValue(14000),
            getTariffInfo: jest.fn().mockReturnValue({}),
          },
        },
      ],
    }).compile();

    controller = module.get<TariffController>(TariffController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
