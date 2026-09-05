.pragma library

var STATUS_READY = "ready"
var STATUS_PLAYING = "playing"
var STATUS_PAUSED = "paused"
var STATUS_CRASH = "crash"
var STATUS_GAME_OVER = "game-over"

var COLS = 10
var ROWS = 20

var LANE_LEFT = 0
var LANE_RIGHT = 1

var LANE_X = [1, 6]
var PLAYER_Y = 16
var CAR_WIDTH = 3
var CAR_HEIGHT = 4

var BASE_TICK_MS = 140
var MIN_TICK_MS = 55
var TICK_LEVEL_STEP = 9
var TURBO_FACTOR = 0.44

// Guaranteed minimum row gap between consecutive cars in DIFFERENT lanes.
var MIN_OPPOSITE_LANE_GAP = 12
var MIN_SAME_LANE_GAP = 10

// Boost / Turbo Energy System
var MAX_BOOST = 100
var BOOST_DRAIN_PER_TICK = 3.0       // ~33 ticks of boost (~1.5 - 2 seconds continuous burn)
var BOOST_PASS_CAR_BONUS = 25        // +25% boost recharge per car dodged
var BOOST_PASSIVE_RECHARGE = 0.45    // Slow trickle recharge when cruising at normal speed

var CAR_PIXELS = [
  [0, 1, 0],
  [1, 1, 1],
  [0, 1, 0],
  [1, 1, 1]
]

function create(randomFn) {
  return {
    cols: COLS,
    rows: ROWS,
    status: STATUS_READY,
    playerLane: LANE_LEFT,
    pendingLane: null,
    turbo: false,
    boost: MAX_BOOST,
    score: 0,
    carsPassed: 0,
    level: 1,
    roadOffset: 0,
    enemies: [],
    spawnCooldown: 8,
    nextEnemyId: 1,
    crashTicks: 0,
    consecutiveSameLane: 0,
    events: [],
    tickMs: BASE_TICK_MS
  }
}

function calculateTickMs(level, turbo) {
  var base = Math.max(MIN_TICK_MS, BASE_TICK_MS - (level - 1) * TICK_LEVEL_STEP)
  if (turbo) return Math.max(22, Math.floor(base * TURBO_FACTOR))
  return base
}

function steer(state, targetLane) {
  if (state.status !== STATUS_PLAYING && state.status !== STATUS_READY) return state
  var lane = targetLane === LANE_RIGHT ? LANE_RIGHT : LANE_LEFT
  if (state.playerLane === lane && !state.pendingLane) return state

  var next = copyState(state)
  next.pendingLane = lane
  return next
}

function setTurbo(state, active) {
  var isTurbo = active === true

  // Cannot activate boost if tank is empty
  if (isTurbo && state.boost <= 0) {
    isTurbo = false
  }

  if (state.turbo === isTurbo) return state

  var next = copyState(state)
  next.turbo = isTurbo
  next.tickMs = calculateTickMs(next.level, next.turbo)
  if (isTurbo && next.status === STATUS_PLAYING) {
    next.events.push("turbo")
  }
  return next
}

function togglePause(state) {
  if (state.status === STATUS_PLAYING) {
    var paused = copyState(state)
    paused.status = STATUS_PAUSED
    paused.events.push("pause")
    return paused
  }
  if (state.status === STATUS_PAUSED || state.status === STATUS_READY) {
    var playing = copyState(state)
    playing.status = STATUS_PLAYING
    playing.events.push("play")
    return playing
  }
  return state
}

function pause(state) {
  if (state.status === STATUS_PLAYING) {
    var next = copyState(state)
    next.status = STATUS_PAUSED
    return next
  }
  return state
}

function restart(state) {
  var next = create()
  next.status = STATUS_PLAYING
  next.events.push("start")
  return next
}

function start(state) {
  var next = create()
  next.status = STATUS_PLAYING
  next.events.push("start")
  return next
}

function copyEnemy(enemy) {
  return {
    id: enemy.id,
    lane: enemy.lane,
    y: enemy.y,
    passed: enemy.passed
  }
}

function copyState(state) {
  var enemies = []
  for (var i = 0; i < state.enemies.length; i++) {
    enemies.push(copyEnemy(state.enemies[i]))
  }

  return {
    cols: state.cols,
    rows: state.rows,
    status: state.status,
    playerLane: state.playerLane,
    pendingLane: state.pendingLane,
    turbo: state.turbo,
    boost: state.boost !== undefined ? state.boost : MAX_BOOST,
    score: state.score,
    carsPassed: state.carsPassed,
    level: state.level,
    roadOffset: state.roadOffset,
    enemies: enemies,
    spawnCooldown: state.spawnCooldown,
    nextEnemyId: state.nextEnemyId,
    crashTicks: state.crashTicks,
    consecutiveSameLane: state.consecutiveSameLane || 0,
    events: [],
    tickMs: state.tickMs
  }
}

function checkCollision(playerLane, enemies) {
  for (var i = 0; i < enemies.length; i++) {
    var enemy = enemies[i]
    if (enemy.lane !== playerLane) continue
    if (enemy.y + CAR_HEIGHT > PLAYER_Y && enemy.y < PLAYER_Y + CAR_HEIGHT) {
      return true
    }
  }
  return false
}

function step(state, randomFn) {
  if (state.status === STATUS_READY || state.status === STATUS_PAUSED || state.status === STATUS_GAME_OVER) {
    return state
  }

  var next = copyState(state)
  next.events = []

  // Handle crash countdown animation
  if (next.status === STATUS_CRASH) {
    next.crashTicks--
    if (next.crashTicks <= 0) {
      next.status = STATUS_GAME_OVER
      next.events.push("gameover")
    }
    return next
  }

  // Handle Boost Consumption / Passive Recharge
  if (next.turbo) {
    next.boost = Math.max(0, next.boost - BOOST_DRAIN_PER_TICK)
    if (next.boost <= 0) {
      next.turbo = false
      next.events.push("boost_empty")
    }
  } else {
    next.boost = Math.min(MAX_BOOST, next.boost + BOOST_PASSIVE_RECHARGE)
  }

  // Apply lane steering
  if (next.pendingLane !== null) {
    if (next.pendingLane !== next.playerLane) {
      next.playerLane = next.pendingLane
      next.events.push("steer")
    }
    next.pendingLane = null
  }

  // Advance road border dots
  next.roadOffset = (next.roadOffset + 1) % 4

  // Move enemy cars downwards
  var activeEnemies = []
  var carsPassedThisStep = 0

  for (var i = 0; i < next.enemies.length; i++) {
    var enemy = next.enemies[i]
    enemy.y += 1

    // Check if player safely passed the enemy car
    if (!enemy.passed && enemy.y >= PLAYER_Y + CAR_HEIGHT) {
      enemy.passed = true
      carsPassedThisStep++
    }

    // Keep car if still visible on or near board
    if (enemy.y < ROWS) {
      activeEnemies.push(enemy)
    }
  }
  next.enemies = activeEnemies

  // Check collision with player car
  if (checkCollision(next.playerLane, next.enemies)) {
    next.status = STATUS_CRASH
    next.crashTicks = 8
    next.events.push("crash")
    return next
  }

  // Update score, level progression & boost recharge rewards
  if (carsPassedThisStep > 0) {
    var passPoints = carsPassedThisStep * (next.turbo ? 20 : 10)
    next.score += passPoints
    next.carsPassed += carsPassedThisStep
    next.events.push("score")

    // Bonus boost refill when dodging cars!
    next.boost = Math.min(MAX_BOOST, next.boost + carsPassedThisStep * BOOST_PASS_CAR_BONUS)

    var newLevel = Math.min(10, 1 + Math.floor(next.carsPassed / 8))
    if (newLevel > next.level) {
      next.level = newLevel
      next.boost = MAX_BOOST // Full refill on level up!
      next.events.push("levelup")
    }
  }

  // Small bonus point for continuous distance in turbo
  if (next.turbo && next.roadOffset === 0) {
    next.score += 1
  }

  // Enemy spawning logic with GUARANTEED safe lane switching at all speeds
  next.spawnCooldown--
  if (next.spawnCooldown <= 0) {
    var randVal = randomFn ? Number(randomFn()) : Math.random()
    if (!isFinite(randVal)) randVal = 0

    var last = next.enemies.length > 0 ? next.enemies[next.enemies.length - 1] : null

    var candidateLane = randVal < 0.5 ? LANE_LEFT : LANE_RIGHT

    // Avoid 3 in a row on the same lane
    if (last && next.consecutiveSameLane >= 2) {
      candidateLane = (last.lane === LANE_LEFT) ? LANE_RIGHT : LANE_LEFT
    }

    var isOpposite = last && (last.lane !== candidateLane)
    var requiredGap = isOpposite ? MIN_OPPOSITE_LANE_GAP : MIN_SAME_LANE_GAP

    if (last && (last.y + CAR_HEIGHT < requiredGap)) {
      next.spawnCooldown = 1
    } else {
      next.enemies.push({
        id: next.nextEnemyId++,
        lane: candidateLane,
        y: -CAR_HEIGHT,
        passed: false
      })

      if (last && last.lane === candidateLane) {
        next.consecutiveSameLane = (next.consecutiveSameLane || 0) + 1
      } else {
        next.consecutiveSameLane = 1
      }

      var extraVariance = Math.floor((randomFn ? Number(randomFn()) : Math.random()) * 4)
      next.spawnCooldown = requiredGap + extraVariance
    }
  }

  next.tickMs = calculateTickMs(next.level, next.turbo)
  return next
}

function isPixelLit(state, col, row) {
  if (col < 0 || col >= COLS || row < 0 || row >= ROWS) return false

  // 1. Road borders (col 0 and col 9)
  if (col === 0 || col === 9) {
    return ((row + state.roadOffset) % 4) < 2
  }

  // 2. Crash flickering effect
  if (state.status === STATUS_CRASH) {
    if (state.crashTicks % 2 === 0) {
      var pX = LANE_X[state.playerLane]
      if (col >= pX - 1 && col <= pX + CAR_WIDTH && row >= PLAYER_Y - 1 && row <= PLAYER_Y + CAR_HEIGHT) {
        return ((col + row + state.crashTicks) % 2) === 0
      }
    }
  }

  // 3. Player car
  var playerX = LANE_X[state.playerLane]
  if (col >= playerX && col < playerX + CAR_WIDTH && row >= PLAYER_Y && row < PLAYER_Y + CAR_HEIGHT) {
    var cX = col - playerX
    var cY = row - PLAYER_Y
    if (CAR_PIXELS[cY][cX] === 1) return true
  }

  // 4. Enemy cars
  for (var i = 0; i < state.enemies.length; i++) {
    var enemy = state.enemies[i]
    var enemyX = LANE_X[enemy.lane]
    if (col >= enemyX && col < enemyX + CAR_WIDTH && row >= enemy.y && row < enemy.y + CAR_HEIGHT) {
      var eX = col - enemyX
      var eY = row - enemy.y
      if (eY >= 0 && eY < CAR_HEIGHT && CAR_PIXELS[eY][eX] === 1) return true
    }
  }

  return false
}

function cellLit(state, index) {
  var col = index % COLS
  var row = Math.floor(index / COLS)
  return isPixelLit(state, col, row)
}

function formatDigits(num, places) {
  var s = String(Math.max(0, Math.floor(num || 0)))
  while (s.length < places) s = "0" + s
  return s
}
