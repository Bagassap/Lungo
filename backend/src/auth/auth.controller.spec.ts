import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { ExecutionContext } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

const mockGuard = { canActivate: (_ctx: ExecutionContext) => true };

describe('AuthController', () => {
  let controller: AuthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: {
            sendOtp: jest.fn(),
            completeRegistration: jest.fn(),
            register: jest.fn(),
            verifyOtp: jest.fn(),
            login: jest.fn(),
            refreshToken: jest.fn(),
            quickLogin: jest.fn(),
            selectRole: jest.fn(),
            logout: jest.fn(),
          },
        },
        { provide: ConfigService, useValue: { get: jest.fn() } },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(mockGuard)
      .compile();

    controller = module.get<AuthController>(AuthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
