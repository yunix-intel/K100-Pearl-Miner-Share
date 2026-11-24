[English](README.md) | [简体中文](README.zh-CN.md) | **한국어** | [日本語](README.ja.md)

# K100 Pearl (PRL) 마이너

하이곤 K100_AI (gfx928 DCU) 용 Pearl (PRL) 채굴 소프트웨어입니다.
**바이너리로만 배포되며 소스 코드는 포함되지 않습니다.**

---

## 📦 다운로드

**[➡️ v1.0.3 다운로드](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/tag/v1.0.3)**

| | |
|---|---|
| 패키지 | `k100-miner-v1.0.3-linux-x64.tar.gz` |
| 크기 | 31.3 MB |
| SHA256 | `9aa31730914424adea8ea4e72d8c47f18c43d5e5d77fec59574105b28ab84b36` |

```bash
wget https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/download/v1.0.3/k100-miner-v1.0.3-linux-x64.tar.gz
sha256sum k100-miner-v1.0.3-linux-x64.tar.gz          # 위의 SHA256과 일치해야 합니다
tar xzf k100-miner-v1.0.3-linux-x64.tar.gz
cd k100-miner-v1.0.3-linux-x64
sudo ./install.sh
```

> **이 저장소에는 문서만 있습니다.** 바이너리는 [Releases 페이지](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases)를
> 통해서만 배포하며, 미러는 제공하지 않습니다.

---


> ## ⚠️ 개발자 수수료 고지 — 사용 전에 반드시 읽어주세요
>
> **이 소프트웨어는 채굴 시간의 2.0%를 개발자에게 사용합니다.**
>
> | | |
> |---|---|
> | **비율** | **2.0%**, *시간* 기준으로 엄격히 정산 (72시간 시뮬레이션: 1.991%) |
> | **개발자 지갑** | **바이너리 내부 XOR 난독화 + 체크섬 — 평문 사본 없음** |
> | **지갑 지문** | `sha256:6050486ad79f` (앞 12자리 16진수) |
> | **시작 시** | `[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)` 출력 |
> | **채굴 중** | 계정 전환 때마다 누적 비율을 출력 — 2.0% 근처인지 직접 확인 가능 |
> | **비활성화** | `DEV_FEE_PERMILLE=0` (자가 테스트용; 끄면 수수료 없음) |
>
> ### 검증 가능성에 대한 정직한 설명
>
> 지갑은 **XOR 난독화 + 체크섬**으로 저장되며, **암호학적 의미의 암호화가 아닙니다.**
> `strings`로는 찾을 수 없지만, 바이너리 페이로드를 압축 해제하면 몇 분 만에 주소를
> 복원할 수 있습니다. **우리는 숨겨져 있다고 주장하지 않습니다.**
>
> **실제로 강제되는 것은 무결성입니다**: 지갑 암호문, 키, 체크섬 중 하나라도
> 수정하면 프로그램이 시작을 거부합니다(`exit code 3`). 따라서 수수료 지급 대상을
> 바꾸거나 패치로 끌 수 없습니다.
>
> 로그에서 검증할 수 있는 것: **비율이 실제로 2.0%라는 점** (계정 전환 시마다 누적 통계 출력).
>
> **암호학적으로 숨겨진 수취인이 필요하다면 이 소프트웨어를 사용하지 마세요.**
>
> **이 비율을 받아들일 수 없다면 이 소프트웨어를 사용하지 마세요.**

---

## 목차

- [📦 다운로드](#-다운로드)
- [개요](#개요)
- [요구 사항](#요구-사항)
- [설치](#설치)
- [사용법](#사용법)
- [상태 확인](#상태-확인)
- [중지](#중지)
- [개발자 수수료 동작 방식](#개발자-수수료-동작-방식)
- [자주 묻는 질문](#자주-묻는-질문)
- [문제 해결](#문제-해결)
- [버전 및 라이선스](#버전-및-라이선스)

---

## 개요

8장 K100_AI 시스템을 위한 완전한 Pearl 채굴 솔루션입니다.
실측 **620 TH/s** (8장, 풀 집계 기준).

| 항목 | 값 |
|---|---|
| 카드당 해시레이트 | 72 TH/s |
| 8장 합계 | 620 TH/s (풀 표시값; 롤링 윈도우가 채워지며 상승) |
| attempt 당 | 15.38 ms |
| 전력 | 400 W/카드 (`power1_cap_max` — 하드웨어 상한) |
| 온도 | Tj 78–82 °C |

> **⚠️ 풀에 표시되는 해시레이트 ≈ 실제값 × (가동 분 / 60).**
> 시작 직후에는 약 1/3만 표시되며, 1시간이 지나야 정확해집니다.

### 동작 방식 (개략)

```
1. 풀에서 job(header + target)을 파싱하고 job key를 도출
2. GPU에서 A/B 노이즈 행렬 생성
3. 매 attempt: A측 선택집합 준비 후 MMA 커널 실행
4. 히트 시: GPU가 계산한 chunk CV를 재사용해 proof를 로컬 생성·제출
5. 풀은 ~43초마다 새 job 발행; B측은 job별로 캐시 (reuse-B)
```

---

---

## 다운로드 검증

**이 저장소의 Release 페이지가 유일한 공식 배포 채널입니다.** 미러는 없습니다.

```bash
sha256sum k100-miner-v1.0.3-linux-x64.tar.gz
```

v1.0.1 의 올바른 값:

```
9aa31730914424adea8ea4e72d8c47f18c43d5e5d77fec59574105b28ab84b36
```

**체크섬이 일치하지 않으면 실행하지 마세요.** 누군가 다시 패키징한 것입니다.
삭제하고 Release 페이지에서 다시 다운로드하세요.

전체 무결성 정책과 공급망 이슈 신고 방법은 [SECURITY.md](SECURITY.md) 를 참조하세요.

## 요구 사항

| 항목 | 요구 |
|---|---|
| **하드웨어** | 하이곤 K100_AI (gfx928) DCU, 8장 권장 |
| **드라이버** | 하이곤 DTK **26.04** (`/opt/dtk/dtk-26.04`) |
| **OS** | Linux x86_64, glibc **≥ 2.14** (바이너리 요구사항; Kylin V10 / glibc 2.28 에서 실측) |
| **메모리** | ≥ 16 GB |
| **디스크** | ≥ 200 MB (설치 트리) |
| **`/tmp`** | 카드당 약 130 MB (Nuitka 프로세스당 약 123 MB 압축 해제); 8장 ≈ 1 GB |
| **CPU** | 튜닝된 코어 고정표는 ≥116 논리 코어 필요; 그 미만이면 균등 분배로 자동 전환 |
| **네트워크** | 풀까지 아웃바운드 TCP 8048 |
| **권한** | root (`/opt/vllm-fork`에 설치) |

### 지원 풀

```
prl-hk.kryptex.network:8048   (TLS, type:v2 / gzip proof)
```

> 풀 엔드포인트는 컴파일되어 있습니다. 계정(`--account WALLET/WORKER`)만
> 사용자가 지정합니다.

---

## 설치

### 1단계 — DTK 설치 확인

```bash
ls /opt/dtk/dtk-26.04/bin/hipcc    # 존재해야 함
/opt/dtk/dtk-26.04/bin/rocm-smi    # K100_AI 8장이 보여야 함
```

실패하면 하이곤 DTK 26.04를 먼저 설치하세요. **없으면 마이너가 시작되지 않습니다.**

### 2단계 — 압축 해제

> 아직 다운로드하지 않셨나요? 상단의 [📦 다운로드](#-다운로드)를 참고하세요.


```bash
tar xzf k100-miner-v1.0.3-linux-x64.tar.gz
cd k100-miner-v1.0.3-linux-x64
```

내용:

```
k100-miner        마이너 (단일 실행 파일)
libpearl5.so      GPU 커널 라이브러리
install.sh        설치 스크립트
README.md         이 문서
LICENSE           라이선스
CHANGELOG.md      변경 기록
```

### 3단계 — 설치

```bash
sudo ./install.sh
```

설치 스크립트는 먼저 **7개 항목 의존성 점검**(DTK 26.04, `hipcc`, `rocm-smi`,
감지된 카드 수, glibc ≥ 2.14, `python3`, 패키지 파일)을 수행합니다.
하나라도 실패하면 **아무것도 설치하지 않고 중단**하며 종료 코드는 2입니다.

설치 스크립트가 배치하는 것:

```
/opt/vllm-fork/k100-miner          실행 파일
/opt/vllm-fork/libpearl5.so        GPU 라이브러리
/opt/vllm-fork/start.sh            8장 런처 (CPU 고정 포함)
/opt/vllm-fork/stop.sh             전체 중지
/opt/vllm-fork/stat.sh             상태 보고
/var/log/vllm-fork/                로그 디렉터리
```

설치 확인:

```bash
ls -l /opt/vllm-fork/
/opt/vllm-fork/k100-miner --help
```

---

## 사용법

### 단일 카드 스모크 테스트 (먼저 이것부터)

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH

HIP_VISIBLE_DEVICES=0 /opt/vllm-fork/k100-miner \
    --account YOUR_WALLET/YOUR_WORKER \
    --m 8192 --n 65536 --k 2048
```

**10초 이내에 보여야 하는 출력:**

```
[init] m=8192 n=65536 k=2048
[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)
[transport] TLS prl-hk.kryptex.network:8048 (TLSv1.3)
[transport] gzip proof negotiated (type:v2)
[transport] authorize id=3 result=True error=None
[session] {"header": "...", "height": "...", "job_id": "...", "target": "..."}
[init] nbits=0x... cert=3 sess_key=...
[session] backend ready ...
[compute] #10 hit=0 15.4ms MAC 71.8 TH/s
```

**✅ `authorize ... result=True` 와 `[compute]` 줄이 보이면 연결되어 채굴 중입니다.**

> ⚠️ `authorize result=True` 는 풀이 넘겨받은 **문자열**을 받아들였다는 뜻일 뿐,
> 지갑이 실제로 존재하는지는 검증하지 않습니다. `TEST/TESTW` 같은 임시값도
> `result=True` 가 되고 share 까지 수락됩니다. **반드시 본인의 실제 지갑을 사용하고**,
> 잔액은 풀 대시보드에서 확인하십시오. 그것이 유일한 확실한 검증입니다.

**❌ `target` 이 전부 0이거나 `[compute]` 줄이 없으면 중지하고 [문제 해결](#문제-해결)을 보세요.**

### 8장 운영

```bash
# 런처가 각 카드를 서로 겹치지 않는 논리 CPU 코어 4개에 고정합니다
sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

선택: 전력 상한 변경 (기본 400 W = 하드웨어 최대)

```bash
POWER_W=350 sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

### 파라미터

| 파라미터 | 기본값 | 설명 |
|---|---|---|
| `--account` | **필수** | 풀 계정, 형식 `WALLET/WORKER` |
| `--m` | 8192 | A 행렬 행 수 (128의 배수) |
| `--n` | 65536 | B 행렬 열 수 (128의 배수) |
| `--k` | 2048 | 공통 차원 (32의 배수; ≥ 16 × rank = 2048) |
| `--attempts` | 0 | 해당 횟수 후 종료; 0 = 무제한 |
| `--dry-run` | off | 실제 제출 안 함, 출력만 |
| `--test-job` | off | **풀에 접속하지 않음**; `target = 0` 인 가짜 job 사용 |

> **⚠️ 실제 채굴에는 절대 `--test-job` 을 쓰지 마세요.** 가짜 job(`target = 0`,
> 히트 확률 0)을 채굴하므로 풀에는 오프라인으로 보이고 수익이 없습니다.

### 환경 변수

| 변수 | 설명 |
|---|---|
| `HIP_VISIBLE_DEVICES` | 카드 선택, 예: `0` 또는 `0,1,2,3` |
| `DEV_FEE_PERMILLE` | 개발자 수수료 (천분율, 기본 `20` = 2.0%). `0` 이면 비활성 |
| `LD_LIBRARY_PATH` | `/opt/dtk/dtk-26.04/lib64` 포함 필수 |

### 정상 성능 지표

| 지표 | 기대값 |
|---|---|
| attempt 당 | 15.0 – 16.5 ms |
| 카드당 | 68 – 73 TH/s |
| 8장 | 550 – 580 TH/s (로컬 측정) |
| 전력 | 400 W 상한에서 카드당 약 395 – 400 W |
| Tj | 78 – 82 °C |

---

## 상태 확인

```bash
/opt/vllm-fork/stat.sh
```

출력 예:

```
=== 카드별 해시레이트 ===
  gpu0   72.1 TH/s
  gpu1   71.8 TH/s
  ...
  ═══════════════
  합계 574 TH/s

=== share ===
  로컬 적중(MATCH)= 386
  제출(publish)=    384
  수락=             383
  거부=             3

=== devfee 상태 ===
  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 2 次
```

### 수동 확인

```bash
# 실제로 풀에 접속했는가
grep 'authorize id=3 result=True' /var/log/vllm-fork/gpu0.log | head -1

# share 집계
# 주의: authorize 응답도 result=True를 포함합니다 — '◀ id=' 로 실제 share 응답만 필터
grep -c '\[MATCH\] ★★★'  /var/log/vllm-fork/gpu*.log                        # 로컬 적중
grep -c '\[publish\] job='  /var/log/vllm-fork/gpu*.log                      # 제출됨
grep '◀ id=' /var/log/vllm-fork/gpu*.log | grep -c 'result=True'    # 수락
grep '◀ id=' /var/log/vllm-fork/gpu*.log | grep -c 'result=False'   # 거부

# 개발자 수수료 — 2.0% 근처인지 확인
grep 'devfee' /var/log/vllm-fork/gpu*.log | tail -5
```

> **풀 표시 해시레이트 안내:** 약 60분 롤링 평균입니다.
> 시작 직후에는 실제값의 약 1/3만 보입니다. **정상이며** share 손실이 아닙니다.

---

## 중지

```bash
sudo /opt/vllm-fork/stop.sh
```

확인:

```bash
ps -ef | grep -c '[k]100-miner'    # 0 이어야 함
```

---

## 개발자 수수료 동작 방식

**숨기지 않습니다. 전체 메커니즘은 다음과 같습니다.**

### 1. share 개수가 아닌 시간 기준 쿼터

```
사용자를 위해 49초 채굴할 때마다 개발자에게 1초를 배정 (2%)
need = user_s × p/(1−p) 공식으로 장기 비율이 편향되지 않게 유지
```

순진한 방식은 실패합니다:

- "owed > 0 이면 전환"은 과다 지급 (사용자 job 1개 후 dev job 1개 ≈ 50%)
- "dev 초만큼 차감"은 과소 지급 (dev 구간 자체도 적립되어야 함)

### 2. job 경계에서만 전환

```
풀은 ~43초마다 새 job을 발행합니다. 개발자 계정으로 전환할 때 재인증하며
로그에서 확인할 수 있습니다:

  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 1 次
```

### 3. 지갑은 바이너리 내부에 암호화

```
개발자 지갑은 평문 상수가 아닙니다. XOR 암호문 + SHA256 무결성 검사입니다.

- 바이너리에 `strings` 를 걸어도 주소 조각이 나오지 않음
- 암호문이나 체크섬 1바이트만 바꿔도 시작 시 exit code 3
```

### 4. 검증할 수 있는 것과 없는 것

| | |
|---|---|
| ✅ **검증 가능** | 비율이 실제로 2.0% (로그 누적 통계) |
| ⚠️ **노력하면 복원 가능** | 주소는 XOR 난독화이며 암호학적 은닉이 아님 — 페이로드를 풀면 몇 분 만에 복원 |
| ✅ **단, 변경 불가** | 암호문 / 키 / 체크섬 중 하나라도 수정하면 프로그램이 시작 거부 (`exit 3`) |

**⇒ 암호학적으로 숨겨진 수취 지갑이 필요하다면 이 소프트웨어를 사용하지 마세요.**

---

## 자주 묻는 질문

### Q1. `libpearl5.so: cannot open shared object file`

GPU 라이브러리가 `/opt/vllm-fork/libpearl5.so` 에 없습니다.
`sudo ./install.sh` 를 다시 실행하거나 `libpearl5.so` 를 직접 복사하세요.

### Q2. `hipGetDeviceCount() = 0`

`LD_LIBRARY_PATH` 에 `lib64` 가 빠졌습니다:

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH
```

### Q3. 풀에서 오프라인으로 보임 / 해시레이트 0

1. 로그에 `authorize ... result=True` 가 있는지 확인
2. `--account` 가 `WALLET/WORKER` (사이에 슬래시) 인지 확인
3. **`--test-job` 을 넣지 않았는지 확인** — 가짜 job을 채굴해 풀에는 아무것도 안 보임

### Q4. `integrity check failed` 후 종료

내장 개발자 지갑의 SHA256 검사 실패 — 바이너리가 변조되었습니다.
공식 릴리스에서 다시 다운로드하세요.

### Q5. 전력이 280 W까지만 오르고 해시레이트가 낮음

수동 실행 대신 `start.sh` 를 쓰세요 — 카드마다 겹치지 않는 논리 CPU 코어 4개를
고정해 GPU가 CPU측 준비 작업에 굶주리지 않게 합니다.
이 항목만으로 카드당 280 W → 399 W 가 됩니다.

### Q6. 개발자 수수료 비율을 바꿀 수 있나요?

`DEV_FEE_PERMILLE=0` 으로 비활성화됩니다. 다른 값도 동작합니다 (`=10` 은 1%).
**비율을 바꿔도 지갑 무결성 검사에는 영향이 없습니다.**

### Q7. 8장 미만으로 돌릴 수 있나요?

가능합니다. `HIP_VISIBLE_DEVICES=0,1` 이면 2장입니다. 해시레이트는 대체로 선형입니다.

### Q8. 풀 표시가 `stat.sh` 보다 낮은 이유?

풀은 약 60분 롤링 평균입니다. 또한 풀은 1 hash = 1 MAC (M·N·K) 으로 집계하는데
일부 도구는 2·M·N·K (MADD) 로 보고합니다 — 2배 차이입니다.
이 마이너는 MAC 기준으로 기록하며 풀과 일치합니다.

---

## 문제 해결

### 아무 출력도 없음

```bash
/opt/vllm-fork/k100-miner --help     # 바이너리 자체가 실행되는가
ldd /opt/vllm-fork/k100-miner        # 공유 라이브러리가 해결되는가
```

### `authorize ... result=False`

계정 문자열이 틀렸습니다. 정확히 `WALLET/WORKER` 여야 합니다
(kryptex는 회선상 `wallet.worker` 를 쓰며, 마이너가 슬래시를 변환합니다).

### share가 수락되지만 `result=False` 가 높음 (> 6%)

share가 만료되고 있습니다. 풀은 ~43초마다 job을 바꾸고 마이너는 50 attempt마다
새 job을 폴링합니다. 소량 거부(< 6%)는 정상입니다. 훨씬 높다면 풀까지의
네트워크 지연을 확인하세요.

### 온도가 90 °C 초과

전력 상한을 낮추세요:

```bash
POWER_W=300 sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

> 이 카드의 `power1_cap_max` 는 400 W이며, 초과 값은 드라이버가 거부합니다.

### 로그 위치

```
/var/log/vllm-fork/gpu0.log … gpu7.log
```

---

## 버전 및 라이선스

[CHANGELOG.md](CHANGELOG.md) 및 [LICENSE](LICENSE) 참조.

**바이너리 배포 전용 — 소스 코드는 제공되지 않습니다.**

라이선스는 리버스 엔지니어링, 무결성 검사 수정, 개발자 수수료 메커니즘 제거를
금지합니다.

| 버전 | 날짜 | 비고 |
|---|---|---|
| 1.0.3 | 2026-11-24 | **보안 릴리스.** 풀 TLS **엄격 검증**(v1.0.0–v1.0.2 는 `CERT_NONE` 으로 MITM 가능). 라이브러리 경로 하드코딩 제거; `stat.sh` 가 `[MATCH]` 로 집계(출력되지 않는 `[HIT]` 대신), `authorize` 를 share 로 세지 않음; 코어 고정표 자동 감지; 설치 전 기존 파일 백업; `--account` 형식 검증. 문서를 실제 바이너리에 맞게 수정. |
| 1.0.2 | 2026-11-24 | **바이너리 재빌드** (`ea683cbf`). `--help`에서 미사용 `--model`/`--tensor-parallel-size` 등 8개 인자 제거. `stop.sh`가 `/proc/<pid>/exe`로 정확히 매칭(무관 프로세스 오살해 방지). 로그 디렉터리 700/600. 설치 전 의존성 점검. `start.sh`가 `$DST`를 따름. |
| 1.0.1 | 2026-11-24 | 문서 업데이트. 바이너리 변경 없음 (md5 `7d2a12e5`). 패키지 내 README 갱신; 재현 가능한 빌드용 `make_release.sh` 추가. |
| 1.0.0 | 2026-11-10 | 첫 바이너리 릴리스. 카드당 72 TH/s, 8장 620 TH/s. 개발자 수수료 2.0%. |
