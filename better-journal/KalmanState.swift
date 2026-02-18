//
//  KalmanState.swift
//  better-journal
//
//  1D Kalman smoother for mood temporal stabilization.
//  Prevents emotional whiplash by treating each mood observation
//  as a noisy measurement of an underlying latent mood state.
//  Persisted across app launches.
//

import Foundation

// MARK: - Kalman State

/// Persisted 1D Kalman filter state for a single channel (valence or arousal).
///
/// **Predict step**: mood drifts toward baseline between entries.
/// **Update step**: new observation moves the state proportionally to its precision
/// relative to the predicted state's uncertainty.
struct KalmanChannel: Codable, Sendable, Equatable {

    /// Current best estimate.
    var mu: Double

    /// Current uncertainty (variance, σ²).
    var variance: Double

    /// Timestamp of the last update (for time-gap–aware process noise).
    var lastUpdated: Date?

    // MARK: - Predict

    /// Predict the next state given elapsed time.
    ///
    /// - `baseline`: the user's personal mean (or 0 during cold start).
    /// - `persistence`: how strongly the previous state persists (α ∈ [0.7, 0.95]).
    /// - `processNoise`: base Q per 24h. Scaled by hours since last update.
    mutating func predict(
        baseline: Double,
        persistence: Double = 0.85,
        processNoise: Double = 0.04,
        now: Date = Date()
    ) {
        // Scale process noise by time gap
        let hoursSinceLast: Double
        if let last = lastUpdated {
            hoursSinceLast = max(0, now.timeIntervalSince(last) / 3600.0)
        } else {
            hoursSinceLast = 24   // cold start: assume one day
        }
        let timeScaledQ = processNoise * (hoursSinceLast / 24.0)

        // State drifts toward baseline
        mu = persistence * mu + (1 - persistence) * baseline
        variance += timeScaledQ
    }

    // MARK: - Update

    /// Incorporate a new observation.
    ///
    /// - `observation`: the fused value from Bayesian fusion.
    /// - `observationVariance`: σ² of the fused estimate.
    /// - Returns: the Kalman gain K (for diagnostics / explainability).
    @discardableResult
    mutating func update(
        observation: Double,
        observationVariance: Double,
        now: Date = Date()
    ) -> Double {
        // Cap the Kalman gain for extreme outliers (guardrail)
        let rawK = variance / (variance + observationVariance)
        let K = min(rawK, 0.6)       // never let a single observation dominate > 60%

        // Innovation (surprise)
        let innovation = observation - mu
        let innovationMagnitude = abs(innovation)
        let predictedSigma = sqrt(variance)

        // If innovation > 2.5σ, further cap the gain (outlier rejection)
        let effectiveK: Double
        if predictedSigma > 1e-6 && innovationMagnitude > 2.5 * predictedSigma {
            effectiveK = min(K, 0.3)
        } else {
            effectiveK = K
        }

        mu += effectiveK * innovation
        variance = (1 - effectiveK) * variance
        // Floor variance — never become infinitely certain
        variance = max(variance, 0.005)
        lastUpdated = now

        return effectiveK
    }
}

// MARK: - Kalman Smoother (Both Channels)

/// Combined Kalman state for valence + arousal with persistence.
struct KalmanState: Codable, Sendable, Equatable {

    var valence: KalmanChannel
    var arousal: KalmanChannel

    // MARK: - Factory

    /// Cold-start state (wide uncertainty, neutral center).
    static let initial = KalmanState(
        valence: KalmanChannel(mu: 0.0, variance: 0.25, lastUpdated: nil),
        arousal: KalmanChannel(mu: 0.4, variance: 0.04, lastUpdated: nil)
    )

    // MARK: - Full Predict + Update

    /// Run predict → update cycle for both channels.
    mutating func step(
        observedValence: Double,
        observedArousal: Double,
        observedValenceVariance: Double,
        observedArousalVariance: Double,
        baselineValence: Double = 0,
        baselineArousal: Double = 0.4,
        now: Date = Date()
    ) {
        valence.predict(baseline: baselineValence, now: now)
        valence.update(
            observation: observedValence,
            observationVariance: observedValenceVariance,
            now: now
        )
        arousal.predict(baseline: baselineArousal, now: now)
        arousal.update(
            observation: observedArousal,
            observationVariance: observedArousalVariance,
            now: now
        )
    }
}
