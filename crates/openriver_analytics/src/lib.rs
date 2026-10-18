//! Sample-aware aggregates. Individual poker statistic definitions come later.

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error("successes cannot exceed eligible opportunities")]
pub struct InvalidOpportunityCount;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
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
    fn distinguishes_missing_evidence_from_zero_successes() {
        assert_eq!(OpportunityCount::new(0, 0).unwrap().rate(), None);
        assert_eq!(OpportunityCount::new(0, 10).unwrap().rate(), Some(0.0));
        assert_eq!(OpportunityCount::new(3, 10).unwrap().rate(), Some(0.3));
        assert_eq!(OpportunityCount::new(2, 1), Err(InvalidOpportunityCount));
    }
}
