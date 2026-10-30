//! Poker statistics computed from canonical hands.

pub mod aggregate;
pub mod analysis;
pub mod equity;
pub mod evaluator;
#[cfg(test)]
mod golden;
pub mod position;
#[cfg(test)]
mod properties;
pub mod replay;
pub mod stats;
#[cfg(test)]
mod testkit;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error("successes cannot exceed eligible opportunities")]
pub struct InvalidOpportunityCount;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct OpportunityCount {
    successes: u64,
    eligible: u64,
}

impl OpportunityCount {
    pub fn new(successes: u64, eligible: u64) -> Result<Self, InvalidOpportunityCount> {
        if successes > eligible {
            return Err(InvalidOpportunityCount);
        }
        Ok(Self {
            successes,
            eligible,
        })
    }

    pub fn successes(&self) -> u64 {
        self.successes
    }

    /// Record one opportunity and whether it was taken.
    pub fn observe(&mut self, taken: bool) {
        self.eligible += 1;
        self.successes += u64::from(taken);
    }

    /// Combine counts from disjoint sets of hands.
    pub fn merge(&mut self, other: &Self) {
        self.successes += other.successes;
        self.eligible += other.eligible;
    }

    /// Wilson score interval for the true rate at ~95% confidence.
    /// `None` without evidence; wide for small samples by construction.
    pub fn wilson_interval_95(&self) -> Option<(f64, f64)> {
        const Z: f64 = 1.959_963_984_540_054;
        let n = self.eligible as f64;
        if self.eligible == 0 {
            return None;
        }
        let p = self.successes as f64 / n;
        let z2 = Z * Z;
        let denominator = 1.0 + z2 / n;
        let centre = (p + z2 / (2.0 * n)) / denominator;
        let margin = Z * ((p * (1.0 - p) + z2 / (4.0 * n)) / n).sqrt() / denominator;
        Some(((centre - margin).max(0.0), (centre + margin).min(1.0)))
    }

    pub fn sample_size(&self) -> u64 {
        self.eligible
    }

    /// None means no evidence; it must not be displayed as a zero-percent result.
    pub fn rate(&self) -> Option<f64> {
        (self.eligible != 0).then(|| self.successes as f64 / self.eligible as f64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wilson_interval_brackets_the_rate_and_narrows_with_evidence() {
        assert_eq!(OpportunityCount::default().wilson_interval_95(), None);
        let small = OpportunityCount::new(5, 10).unwrap();
        let large = OpportunityCount::new(500, 1000).unwrap();
        let (lo_s, hi_s) = small.wilson_interval_95().unwrap();
        let (lo_l, hi_l) = large.wilson_interval_95().unwrap();
        assert!(lo_s < 0.5 && 0.5 < hi_s && lo_l < 0.5 && 0.5 < hi_l);
        assert!(hi_l - lo_l < hi_s - lo_s);
        // Known value: 0/10 -> [0, 0.2775...]
        let (lo, hi) = OpportunityCount::new(0, 10)
            .unwrap()
            .wilson_interval_95()
            .unwrap();
        assert_eq!(lo, 0.0);
        assert!((hi - 0.2775).abs() < 1e-3, "{hi}");
        let (lo, hi) = OpportunityCount::new(10, 10)
            .unwrap()
            .wilson_interval_95()
            .unwrap();
        assert!((hi - 1.0).abs() < 1e-12 && hi <= 1.0);
        assert!((lo - 0.7225).abs() < 1e-3, "{lo}");
    }

    #[test]
    fn merge_equals_observing_everything_together() {
        let mut a = OpportunityCount::default();
        let mut b = OpportunityCount::default();
        let mut all = OpportunityCount::default();
        for (i, taken) in [true, false, false, true, true].into_iter().enumerate() {
            (if i < 2 { &mut a } else { &mut b }).observe(taken);
            all.observe(taken);
        }
        a.merge(&b);
        assert_eq!(a, all);
    }

    #[test]
    fn distinguishes_missing_evidence_from_zero_successes() {
        assert_eq!(OpportunityCount::new(0, 0).unwrap().rate(), None);
        assert_eq!(OpportunityCount::new(0, 10).unwrap().rate(), Some(0.0));
        assert_eq!(OpportunityCount::new(3, 10).unwrap().rate(), Some(0.3));
        assert_eq!(OpportunityCount::new(2, 1), Err(InvalidOpportunityCount));
    }
}
