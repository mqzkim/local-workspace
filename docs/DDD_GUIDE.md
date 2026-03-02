# DDD (Domain-Driven Design) 전체 가이드

> **이 문서는 워크스페이스의 절대적 아키텍처 기준이다.**
> 신규 프로젝트 시작, 리팩토링, AI 에이전트 작업 시 반드시 이 문서를 먼저 읽는다.

---

## 목차

1. [왜 DDD인가](#1-왜-ddd인가)
2. [핵심 개념](#2-핵심-개념)
3. [레이어 아키텍처](#3-레이어-아키텍처)
4. [표준 폴더 구조](#4-표준-폴더-구조)
5. [도메인 객체 정의](#5-도메인-객체-정의)
6. [의존성 규칙](#6-의존성-규칙)
7. [이벤트 기반 컨텍스트 통신](#7-이벤트-기반-컨텍스트-통신)
8. [워크스페이스 바운디드 컨텍스트 맵](#8-워크스페이스-바운디드-컨텍스트-맵)
9. [기술 스택별 구현 가이드](#9-기술-스택별-구현-가이드)
10. [AI 에이전트 운영 가이드](#10-ai-에이전트-운영-가이드)
11. [Anti-Pattern 목록](#11-anti-pattern-목록)
12. [마이그레이션 전략](#12-마이그레이션-전략)

---

## 1. 왜 DDD인가

### AI 에이전트가 유지보수하기 쉬운 구조의 조건

| 조건 | DDD 해결책 |
|------|-----------|
| 어디를 수정해야 할지 즉시 알 수 있어야 한다 | 레이어 + 바운디드 컨텍스트로 책임 분리 |
| 수정이 의도치 않은 영향을 주면 안 된다 | 의존성 역전 + 이벤트 기반 통신 |
| 비즈니스 로직이 어디 있는지 명확해야 한다 | 도메인 레이어 순수 유지 |
| 새 기능 추가가 기존 코드를 깨지 않아야 한다 | OCP + 도메인 이벤트 |
| 코드가 비즈니스 언어로 읽혀야 한다 | Ubiquitous Language |

### 이 워크스페이스의 적용 범위

- **claude-workspace** (ShipKit, Next.js) → TypeScript DDD
- **trading** (트레이딩 시스템, Python) → Python DDD
- **unity-game** (Unity, C#) → C# DDD

---

## 2. 핵심 개념

### 바운디드 컨텍스트 (Bounded Context)

명확한 경계를 가진 독립적인 비즈니스 영역.

- 컨텍스트 내부에서만 통용되는 언어(Ubiquitous Language) 사용
- 다른 컨텍스트와 직접 의존하지 않음 → **이벤트로만 통신**
- 각자 독립적으로 배포·확장 가능

```
❌ 잘못된 예:
BillingContext.getUser(userId)  # Billing이 User 컨텍스트에 직접 의존

✅ 올바른 예:
UserRegisteredEvent → BillingContext (이벤트 구독으로 처리)
```

### Ubiquitous Language (공통 언어)

도메인 전문가 + 개발자 + AI가 동일한 용어를 사용.

```python
# ❌ 기술 용어 중심
def update_user_score_row(user_id: int, score_value: float):
    ...

# ✅ 도메인 언어 중심
def apply_scoring_result(portfolio_id: PortfolioId, score: CompositeScore):
    ...
```

---

## 3. 레이어 아키텍처

```
┌─────────────────────────────────────┐
│         Presentation Layer          │  ← UI, API, CLI
│   (HTTP, tRPC, CLI, React)          │
├─────────────────────────────────────┤
│         Application Layer           │  ← 유스케이스 조율
│   (Commands, Queries, Handlers)     │
├─────────────────────────────────────┤
│           Domain Layer              │  ← 순수 비즈니스 로직
│  (Entities, VO, Services, Events)   │
├─────────────────────────────────────┤
│       Infrastructure Layer          │  ← 기술 구현체
│   (DB, External API, Messaging)     │
└─────────────────────────────────────┘

의존성 방향: Presentation → Application → Domain ← Infrastructure
```

### 각 레이어의 책임

#### Domain Layer (핵심)
- **책임**: 비즈니스 규칙, 불변식(invariant) 보장
- **허용**: 순수 로직, 도메인 객체, 도메인 서비스
- **금지**: 프레임워크, DB 드라이버, HTTP 클라이언트, I/O

#### Application Layer
- **책임**: 유스케이스 조율, 트랜잭션 경계
- **허용**: Domain 객체 사용, Infrastructure 인터페이스 호출
- **금지**: 비즈니스 로직 (로직은 Domain으로), UI 관심사

#### Infrastructure Layer
- **책임**: 외부 시스템 연동 구현
- **허용**: DB ORM, HTTP 클라이언트, 메시지 브로커
- **금지**: 비즈니스 로직, 직접 Presentation 의존

#### Presentation Layer
- **책임**: 사용자 요청 수신, 응답 포맷
- **허용**: Application Layer 호출, DTO 변환
- **금지**: 비즈니스 로직, DB 직접 접근

---

## 4. 표준 폴더 구조

### TypeScript / Next.js (claude-workspace)

```
src/
  domains/
    auth/
      domain/
        entities/
          UserEntity.ts               # class UserEntity { id: UserId; email: Email }
        value-objects/
          EmailVO.ts                  # class EmailVO { validate(): boolean }
          UserIdVO.ts
        aggregates/
          UserAggregate.ts
        events/
          UserRegisteredEvent.ts      # class UserRegisteredEvent implements DomainEvent
          UserDeletedEvent.ts
        services/
          AuthDomainService.ts        # 여러 엔티티에 걸친 도메인 로직
        repositories/
          IUserRepository.ts          # interface IUserRepository (구현 없음)
        index.ts                      # ★ export { UserEntity, IUserRepository, ... }
      application/
        commands/
          RegisterUserCommand.ts      # { email: string; password: string }
          DeleteUserCommand.ts
        queries/
          GetUserQuery.ts
        handlers/
          RegisterUserHandler.ts      # implements CommandHandler<RegisterUserCommand>
          GetUserHandler.ts
        dtos/
          UserResponseDto.ts
        index.ts
      infrastructure/
        persistence/
          PrismaUserRepository.ts     # implements IUserRepository (실제 DB 연동)
          UserMapper.ts               # Entity ↔ DB 모델 변환
        external/
          SupabaseAuthClient.ts
        index.ts
      presentation/
        api/
          authRouter.ts               # tRPC / REST 라우터
        index.ts
      DOMAIN.md                       # ★ AI 필독

    billing/
      domain/ ...
      DOMAIN.md

    trading/
      domain/ ...
      DOMAIN.md

  shared/
    domain/
      DomainEvent.ts                  # interface DomainEvent { occurredOn: Date }
      Entity.ts                       # abstract class Entity<T> { equals(other: T) }
      ValueObject.ts                  # abstract class ValueObject<T>
      AggregateRoot.ts
    utils/
      Result.ts                       # type Result<T, E> = Ok<T> | Err<E>
      Guard.ts                        # 입력 검증 유틸
    types/
      Primitives.ts

  app/                                # Next.js App Router (Presentation만)
    api/
      [domain]/
        route.ts                      # → domains/{domain}/presentation/api/ 위임
```

### Python (trading)

```
trading/
  src/
    regime/                           # 바운디드 컨텍스트: 시장 레짐 분석
      domain/
        entities.py                   # class RegimeEntity
        value_objects.py              # class VIXLevel, class RegimeType
        events.py                     # class RegimeChangedEvent
        services.py                   # class RegimeDetectionService
        repositories.py               # class IRegimeRepository(ABC)
        __init__.py                   # ★ 공개 API
      application/
        commands.py                   # @dataclass class DetectRegimeCommand
        queries.py                    # @dataclass class GetCurrentRegimeQuery
        handlers.py                   # class DetectRegimeHandler
        __init__.py
      infrastructure/
        persistence.py                # class SQLiteRegimeRepository(IRegimeRepository)
        external.py                   # class YFinanceDataClient
        __init__.py
      DOMAIN.md

    scoring/                          # 바운디드 컨텍스트: 종목 스코어링
      domain/ ...
      DOMAIN.md

    signals/                          # 바운디드 컨텍스트: 매매 시그널
      domain/ ...
      DOMAIN.md

    portfolio/                        # 바운디드 컨텍스트: 포트폴리오 관리
      domain/ ...
      DOMAIN.md

    shared/
      domain/
        base_entity.py
        base_value_object.py
        domain_event.py
        result.py                     # Result[T, E] 패턴
      utils/
        decorators.py

  cli/                                # Presentation (CLI)
    commands/
      regime_commands.py              # → regime/application/ 위임

  tests/
    {domain}/                         # 도메인 단위 테스트
      domain/
      application/
      infrastructure/
```

### C# (unity-game)

```
Assets/
  Scripts/
    Domains/
      {DomainName}/
        Domain/
          Entities/
          ValueObjects/
          Events/
          Services/
          Repositories/               # Interface only
        Application/
          Commands/
          Queries/
          Handlers/
        Infrastructure/
          Persistence/
          External/
        DOMAIN.md
    Shared/
      Domain/
        Entity.cs
        ValueObject.cs
        DomainEvent.cs
      Utils/
```

---

## 5. 도메인 객체 정의

### Entity

- **정의**: 고유 식별자(ID)를 가진 객체. ID가 같으면 같은 객체.
- **특징**: 상태가 변할 수 있음, ID로 동일성 판단

```typescript
// TypeScript
class UserEntity extends Entity<UserId> {
  private _email: EmailVO;
  private _name: string;

  // 도메인 메서드 = 비즈니스 행위
  changeEmail(newEmail: EmailVO): Result<void, DomainError> {
    if (!newEmail.isValid()) return Err(new InvalidEmailError());
    this._email = newEmail;
    this.addDomainEvent(new UserEmailChangedEvent(this.id, newEmail));
    return Ok(undefined);
  }
}
```

### Value Object (VO)

- **정의**: 식별자 없이 속성 값으로만 동일성 판단
- **특징**: 불변(immutable), 교체 방식으로 변경

```typescript
class EmailVO extends ValueObject<{ value: string }> {
  static create(email: string): Result<EmailVO, DomainError> {
    if (!email.includes('@')) return Err(new InvalidEmailError());
    return Ok(new EmailVO({ value: email }));
  }
  get value(): string { return this.props.value; }
}
```

### Aggregate

- **정의**: 일관성 경계. 하나의 트랜잭션에서 함께 변경되는 객체 그룹.
- **규칙**: 외부에서는 Aggregate Root를 통해서만 접근

```typescript
class OrderAggregate extends AggregateRoot<OrderId> {
  private _items: OrderItemEntity[];

  addItem(product: ProductId, qty: Quantity): Result<void, DomainError> {
    // 불변식 검증: 주문 항목 수 제한
    if (this._items.length >= 100) return Err(new OrderLimitExceededError());
    this._items.push(new OrderItemEntity(product, qty));
    return Ok(undefined);
  }
}
```

### Domain Event

- **정의**: 과거에 발생한 도메인 사건. 불변.
- **역할**: 바운디드 컨텍스트 간 통신 수단

```typescript
class UserRegisteredEvent implements DomainEvent {
  readonly occurredOn: Date;
  constructor(
    readonly userId: UserId,
    readonly email: EmailVO,
  ) {
    this.occurredOn = new Date();
  }
}
```

### Domain Service

- **사용 조건**: 로직이 여러 Aggregate/Entity에 걸쳐 있을 때
- **금지**: Entity·VO에 자연스럽게 속하는 로직을 Service로 만들지 말 것

```typescript
class TransferDomainService {
  transfer(from: AccountAggregate, to: AccountAggregate, amount: MoneyVO): Result<void, DomainError> {
    // 두 Aggregate에 걸친 로직 → Domain Service가 담당
    const debitResult = from.debit(amount);
    if (debitResult.isErr()) return debitResult;
    to.credit(amount);
    return Ok(undefined);
  }
}
```

### Repository Interface (Domain에 정의)

```typescript
// domain/repositories/IUserRepository.ts
export interface IUserRepository {
  findById(id: UserId): Promise<UserEntity | null>;
  save(user: UserEntity): Promise<void>;
  delete(id: UserId): Promise<void>;
}

// infrastructure/persistence/PrismaUserRepository.ts
export class PrismaUserRepository implements IUserRepository {
  async findById(id: UserId): Promise<UserEntity | null> {
    const row = await prisma.user.findUnique({ where: { id: id.value } });
    return row ? UserMapper.toDomain(row) : null;
  }
}
```

---

## 6. 의존성 규칙

### 허용 의존성

```
Presentation  →  Application  →  Domain
                                    ↑
Infrastructure  ─────────────────────
```

### 금지 의존성 (절대 금지)

```
Domain → Application          ❌
Domain → Infrastructure       ❌
Domain → Presentation         ❌
Application → Presentation    ❌
Infrastructure → Application  ❌ (이벤트 발행 제외)
컨텍스트A → 컨텍스트B (직접)  ❌ (이벤트만 허용)
```

### index.ts 공개 API 규칙

```typescript
// domains/auth/domain/index.ts
// ★ 이 파일에 없는 것은 외부에서 import 불가

export { UserEntity } from './entities/UserEntity';
export { EmailVO } from './value-objects/EmailVO';
export type { IUserRepository } from './repositories/IUserRepository';
export { UserRegisteredEvent } from './events/UserRegisteredEvent';

// ❌ 내부 구현 세부사항은 노출 안 함
// UserMapper, UserEntityProps 등
```

---

## 7. 이벤트 기반 컨텍스트 통신

### 바운디드 컨텍스트 간 통신 패턴

```
[Auth Context]                    [Billing Context]
UserAggregate
  .registerUser()
  → UserRegisteredEvent 발행        구독 → BillingHandler
                                           .createFreeTrialSubscription()
```

### 구현 예시 (TypeScript)

```typescript
// shared/domain/DomainEvent.ts
export interface DomainEvent {
  readonly occurredOn: Date;
  readonly eventType: string;
}

// domains/auth/domain/events/UserRegisteredEvent.ts
export class UserRegisteredEvent implements DomainEvent {
  readonly eventType = 'auth.UserRegistered';
  readonly occurredOn = new Date();
  constructor(readonly userId: UserId, readonly email: string) {}
}

// domains/billing/application/handlers/UserRegisteredHandler.ts
export class UserRegisteredHandler {
  async handle(event: UserRegisteredEvent): Promise<void> {
    // Auth 컨텍스트를 직접 import하지 않음
    // 이벤트만 구독
    await this.subscriptionService.createFreeTrial(event.userId);
  }
}
```

---

## 8. 워크스페이스 바운디드 컨텍스트 맵

### ShipKit (claude-workspace)

```
┌──────────┐    UserRegisteredEvent    ┌──────────────┐
│   Auth   │ ─────────────────────→   │   Billing    │
│          │                          │              │
│ - User   │    SubscriptionCreated   │ - Plan       │
│ - Email  │ ←───────────────────── │ - Invoice    │
└──────────┘                          └──────────────┘
     │                                       │
     │ UserRegisteredEvent                   │
     ↓                                       │
┌──────────┐                                 │
│ Onboard  │ ←───────────────────────────────┘
│          │    SubscriptionCreated
│ - Step   │
└──────────┘
```

### Trading System

```
┌──────────┐  MarketDataUpdated  ┌──────────┐  RegimeChanged  ┌──────────┐
│   Data   │ ──────────────────→ │  Regime  │ ──────────────→ │ Scoring  │
│ Ingest   │                     │ Detect   │                  │ Engine   │
└──────────┘                     └──────────┘                  └──────────┘
                                                                     │
                                                              ScoreUpdated
                                                                     ↓
                                                              ┌──────────┐
                                                              │ Signals  │ → SignalGenerated
                                                              └──────────┘        │
                                                                                  ↓
                                                                           ┌──────────┐
                                                                           │Portfolio │
                                                                           │ Manager  │
                                                                           └──────────┘
```

---

## 9. 기술 스택별 구현 가이드

### TypeScript / Next.js

```typescript
// Result 패턴 필수 사용 (예외 대신)
type Result<T, E extends DomainError> = Ok<T> | Err<E>;

// 의존성 주입 (Constructor Injection)
class RegisterUserHandler {
  constructor(
    private readonly userRepo: IUserRepository,       // 인터페이스
    private readonly eventBus: IEventBus,
  ) {}
}

// Zod로 DTO 검증 (Application 레이어)
const RegisterUserCommandSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});
```

### Python (trading)

```python
# dataclass로 Value Object
from dataclasses import dataclass
from typing import NewType

PortfolioId = NewType('PortfolioId', str)

@dataclass(frozen=True)  # frozen=True → 불변
class CompositeScore:
    value: float
    breakdown: dict[str, float]

    def __post_init__(self):
        if not 0 <= self.value <= 100:
            raise ValueError(f"Score must be 0-100, got {self.value}")

# ABC로 Repository 인터페이스
from abc import ABC, abstractmethod

class IScoreRepository(ABC):
    @abstractmethod
    def save(self, portfolio_id: PortfolioId, score: CompositeScore) -> None: ...

    @abstractmethod
    def find_latest(self, portfolio_id: PortfolioId) -> CompositeScore | None: ...

# Result 패턴 (returns 라이브러리)
from returns.result import Result, Success, Failure

def calculate_score(data: MarketData) -> Result['CompositeScore', 'ScoringError']:
    if data.is_insufficient():
        return Failure(InsufficientDataError())
    return Success(CompositeScore(value=75.5, breakdown={}))
```

---

## 10. AI 에이전트 운영 가이드

### 작업 전 필수 절차

1. **대상 도메인 파악**: 수정할 파일이 속한 바운디드 컨텍스트 확인
2. **DOMAIN.md 읽기**: 해당 도메인의 `DOMAIN.md` 필독
3. **레이어 확인**: 파일이 `domain/` / `application/` / `infrastructure/` / `presentation/` 중 어디인지 확인
4. **의존성 방향 체크**: 추가할 import가 레이어 규칙을 위반하지 않는지 확인

### 새 기능 추가 체크리스트

- [ ] 어느 바운디드 컨텍스트에 속하는가?
- [ ] Domain 레이어에 비즈니스 로직을 배치했는가?
- [ ] 인터페이스는 `domain/repositories/`에, 구현은 `infrastructure/`에 있는가?
- [ ] 컨텍스트 간 통신은 이벤트로 하는가?
- [ ] `index.ts`를 통해 공개 API를 노출하는가?
- [ ] `DOMAIN.md`를 업데이트했는가?

### 파일 위치 판단 기준

```
"이 코드에 비즈니스 규칙이 있는가?"       → domain/
"이 코드가 유스케이스를 조율하는가?"       → application/
"이 코드가 DB/API/외부 시스템을 다루는가?" → infrastructure/
"이 코드가 사용자 요청을 받는가?"          → presentation/
```

### 버그 수정 가이드

```
버그 발생
  ↓
1. 어느 레이어에서 발생했는가?
2. 해당 도메인의 DOMAIN.md 확인
3. 비즈니스 규칙 위반인가? → domain/ 수정
   기술적 구현 문제인가? → infrastructure/ 수정
   유스케이스 흐름 문제인가? → application/ 수정
4. 수정 후 의존성 방향 재확인
```

---

## 11. Anti-Pattern 목록

### Smart UI (가장 흔한 실수)

```typescript
// ❌ Presentation에 비즈니스 로직
export async function POST(req: Request) {
  const { userId, amount } = await req.json();

  // 비즈니스 로직이 API 라우터에 있음
  if (amount > 10000) throw new Error("Too large");
  await db.transaction.create({ userId, amount });
}

// ✅ 올바른 방법
export async function POST(req: Request) {
  const command = TransferCommandSchema.parse(await req.json());
  const result = await transferHandler.handle(command);  // Application 위임
  return result.isOk() ? Response.json(result.value) : ...;
}
```

### Anemic Domain Model (빈 도메인)

```typescript
// ❌ 빈 껍데기 Entity (데이터만 있고 행위가 없음)
class Order {
  id: string;
  items: OrderItem[];
  status: string;
  total: number;
}

// ❌ 비즈니스 로직이 Service에 모임
class OrderService {
  cancelOrder(order: Order) {
    if (order.status !== 'pending') throw ...;
    order.status = 'cancelled';  // 외부에서 상태 직접 변경
  }
}

// ✅ Rich Domain Model
class OrderAggregate {
  cancel(): Result<void, DomainError> {
    if (!this._status.isPending()) return Err(new CannotCancelError());
    this._status = OrderStatus.Cancelled;
    this.addDomainEvent(new OrderCancelledEvent(this.id));
    return Ok(undefined);
  }
}
```

### Repository에서 비즈니스 로직 처리

```typescript
// ❌ Repository에 비즈니스 로직
class UserRepository {
  async findActiveUsers(): Promise<User[]> {
    // 비즈니스 규칙 ("활성 유저"의 정의)이 Repository에 있음
    return await db.user.findMany({ where: { lastLoginDays: { lt: 30 } } });
  }
}

// ✅ 비즈니스 규칙은 Domain에
// domain/entities/UserEntity.ts
isActive(): boolean {
  return this._lastLoginAt.daysSince() < 30;
}

// infrastructure/UserRepository.ts
async findAll(): Promise<UserEntity[]> { ... }  // 단순 조회만

// application/handlers/GetActiveUsersHandler.ts
const users = await this.userRepo.findAll();
return users.filter(u => u.isActive());  // 도메인 메서드 사용
```

### God Service

```typescript
// ❌ 모든 로직이 한 Service에
class UserService {
  register() { ... }
  login() { ... }
  updateProfile() { ... }
  deleteAccount() { ... }
  sendWelcomeEmail() { ... }
  createBillingAccount() { ... }  // 다른 컨텍스트 로직까지
}

// ✅ 컨텍스트·유스케이스별 분리
class RegisterUserHandler { ... }         // application/
class AuthDomainService { ... }           // domain/ (여러 엔티티 조율)
class BillingHandler { ... }              // billing 컨텍스트
// 이메일 → UserRegisteredEvent 구독
```

---

## 12. 마이그레이션 전략

### 기존 코드를 DDD로 이전하는 순서

```
1단계: DOMAIN.md 먼저 작성 (코드 변경 없음)
  → 비즈니스 경계를 명확히 문서화

2단계: 폴더 구조 생성 (빈 폴더)
  → 목표 구조를 먼저 만들어 둠

3단계: 신규 기능은 DDD 구조로만 작성

4단계: 기존 코드 점진적 이전
  → 가장 자주 변경되는 영역부터
  → 테스트 먼저 작성 후 이전

5단계: Anti-pattern 제거
  → Smart UI → Handler 위임
  → Anemic Model → Rich Model
```

### trading/ 현재 → 목표 구조

```
현재:                           목표:
trading/
  core/
    regime/ ──────────────→   src/regime/domain/
    scoring/ ─────────────→   src/scoring/domain/
    signals/ ─────────────→   src/signals/domain/
  data/ ────────────────────→ src/shared/infrastructure/
  cli/ ─────────────────────→ cli/ (Presentation 유지)
  commercial/ ──────────────→ src/portfolio/application/
  personal/ ────────────────→ src/portfolio/ (개인 설정)
```

---

## 참고

- 규칙 파일 (항상 로드): `.claude/rules/ddd.md`
- 각 도메인 설명: `{project}/src/{domain}/DOMAIN.md`
- 아키텍처 변경 결정: `AGENTS.md`에 기록

**이 문서는 아키텍처 결정 시에만 변경하며, 변경 시 팀 합의 필요.**
