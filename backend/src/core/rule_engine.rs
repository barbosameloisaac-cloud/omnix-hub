use crate::core::event_pipeline::Event;
use serde::{Deserialize, Serialize};

/// Configurable rule engine for defining defensive detection rules.
/// Rules are declarative, explainable, and can be loaded from JSON config.
///
/// Each rule specifies conditions that an event must meet,
/// and an action to take (alert, tag, escalate risk score).
/// No blocking or destructive actions are taken automatically.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    pub id: String,
    pub name: String,
    pub description: String,
    pub enabled: bool,
    pub conditions: Vec<Condition>,
    pub action: RuleAction,
    pub risk_adjustment: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Condition {
    pub field: ConditionField,
    pub operator: ConditionOp,
    pub value: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConditionField {
    EventKind,
    Source,
    Detail,
    RiskScore,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConditionOp {
    Equals,
    Contains,
    GreaterThan,
    LessThan,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RuleAction {
    /// Add a tag/label to the event for filtering
    Tag,
    /// Adjust the event's risk score
    AdjustRisk,
    /// Generate an alert (logged, shown in UI)
    Alert,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleMatch {
    pub rule_id: String,
    pub rule_name: String,
    pub event_id: String,
    pub action: RuleAction,
    pub risk_adjustment: f64,
    pub explanation: String,
}

pub struct RuleEngine {
    rules: Vec<Rule>,
}

impl RuleEngine {
    pub fn new() -> Self {
        Self {
            rules: Self::default_rules(),
        }
    }

    pub fn from_rules(rules: Vec<Rule>) -> Self {
        Self { rules }
    }

    pub fn load_from_json(json: &str) -> Result<Self, serde_json::Error> {
        let rules: Vec<Rule> = serde_json::from_str(json)?;
        Ok(Self { rules })
    }

    /// Evaluate all enabled rules against an event.
    pub fn evaluate(&self, event: &Event) -> Vec<RuleMatch> {
        let mut matches = Vec::new();

        for rule in &self.rules {
            if !rule.enabled {
                continue;
            }
            if self.all_conditions_met(rule, event) {
                matches.push(RuleMatch {
                    rule_id: rule.id.clone(),
                    rule_name: rule.name.clone(),
                    event_id: event.id.clone(),
                    action: rule.action,
                    risk_adjustment: rule.risk_adjustment,
                    explanation: rule.description.clone(),
                });
            }
        }

        matches
    }

    /// Apply rule matches to adjust an event's risk score.
    pub fn apply_risk_adjustments(matches: &[RuleMatch], base_score: f64) -> f64 {
        let adjustment: f64 = matches
            .iter()
            .filter(|m| m.action == RuleAction::AdjustRisk)
            .map(|m| m.risk_adjustment)
            .sum();
        (base_score + adjustment).clamp(0.0, 10.0)
    }

    pub fn rules_count(&self) -> usize {
        self.rules.len()
    }

    pub fn enabled_rules_count(&self) -> usize {
        self.rules.iter().filter(|r| r.enabled).count()
    }

    fn all_conditions_met(&self, rule: &Rule, event: &Event) -> bool {
        rule.conditions.iter().all(|c| self.check_condition(c, event))
    }

    fn check_condition(&self, condition: &Condition, event: &Event) -> bool {
        let field_value = match condition.field {
            ConditionField::EventKind => event.kind.to_string(),
            ConditionField::Source => event.source.clone(),
            ConditionField::Detail => event.detail.clone(),
            ConditionField::RiskScore => event.risk_score.to_string(),
        };

        match condition.operator {
            ConditionOp::Equals => field_value == condition.value,
            ConditionOp::Contains => field_value.contains(&condition.value),
            ConditionOp::GreaterThan => {
                let a: f64 = field_value.parse().unwrap_or(0.0);
                let b: f64 = condition.value.parse().unwrap_or(0.0);
                a > b
            }
            ConditionOp::LessThan => {
                let a: f64 = field_value.parse().unwrap_or(0.0);
                let b: f64 = condition.value.parse().unwrap_or(0.0);
                a < b
            }
        }
    }

    fn default_rules() -> Vec<Rule> {
        vec![
            Rule {
                id: "R001".into(),
                name: "Threat event alert".into(),
                description: "Alert on any threat detection event".into(),
                enabled: true,
                conditions: vec![Condition {
                    field: ConditionField::EventKind,
                    operator: ConditionOp::Equals,
                    value: "THREAT_DETECTED".into(),
                }],
                action: RuleAction::Alert,
                risk_adjustment: 2.0,
            },
            Rule {
                id: "R002".into(),
                name: "Executable in documents".into(),
                description: "Flag events involving executable patterns in document directories"
                    .into(),
                enabled: true,
                conditions: vec![
                    Condition {
                        field: ConditionField::Detail,
                        operator: ConditionOp::Contains,
                        value: ".exe".into(),
                    },
                    Condition {
                        field: ConditionField::Source,
                        operator: ConditionOp::Contains,
                        value: "Documents".into(),
                    },
                ],
                action: RuleAction::AdjustRisk,
                risk_adjustment: 1.5,
            },
            Rule {
                id: "R003".into(),
                name: "High risk event".into(),
                description: "Escalate events with risk score above 5".into(),
                enabled: true,
                conditions: vec![Condition {
                    field: ConditionField::RiskScore,
                    operator: ConditionOp::GreaterThan,
                    value: "5.0".into(),
                }],
                action: RuleAction::Alert,
                risk_adjustment: 0.0,
            },
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::event_pipeline::EventKind;

    fn make_threat_event() -> Event {
        Event {
            id: "evt-1".into(),
            kind: EventKind::ThreatDetected,
            source: "/home/user/Documents/report.pdf.exe".into(),
            detail: "Detected suspicious .exe in documents".into(),
            timestamp: "2026-01-01T00:00:00Z".into(),
            risk_score: 6.0,
        }
    }

    #[test]
    fn test_default_rules_match_threat() {
        let engine = RuleEngine::new();
        let event = make_threat_event();
        let matches = engine.evaluate(&event);
        // Should match R001 (threat event) and R002 (exe in Documents) and R003 (risk > 5)
        assert!(matches.len() >= 2);
        assert!(matches.iter().any(|m| m.rule_id == "R001"));
    }

    #[test]
    fn test_risk_adjustment() {
        let matches = vec![
            RuleMatch {
                rule_id: "R001".into(),
                rule_name: "test".into(),
                event_id: "e1".into(),
                action: RuleAction::AdjustRisk,
                risk_adjustment: 2.0,
                explanation: "test".into(),
            },
            RuleMatch {
                rule_id: "R002".into(),
                rule_name: "test".into(),
                event_id: "e1".into(),
                action: RuleAction::AdjustRisk,
                risk_adjustment: 1.5,
                explanation: "test".into(),
            },
        ];
        let adjusted = RuleEngine::apply_risk_adjustments(&matches, 3.0);
        assert!((adjusted - 6.5).abs() < f64::EPSILON);
    }
}
