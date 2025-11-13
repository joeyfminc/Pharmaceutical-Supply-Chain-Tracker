# 💊 MedSupply - Pharmaceutical Supply Chain Tracker

A blockchain-based system to track medicines from manufacturing to patient, preventing counterfeit drugs and ensuring pharmaceutical authenticity.

## 🎯 Overview

MedSupply leverages Stacks blockchain smart contracts to create an immutable record of pharmaceutical products throughout the entire supply chain. This system helps combat counterfeit medications by providing transparent tracking from manufacturer to patient.

## ✨ Features

- 🏭 **Manufacturer Registration**: Register medicines with batch numbers, manufacturing dates, and expiry dates
- 🚚 **Supply Chain Tracking**: Track medicine transfers between stakeholders
- 🏪 **Pharmacy Dispensing**: Secure dispensing of medicines to patients with prescription tracking  
- 👨‍⚕️ **Patient Safety**: Verify medicine authenticity and check for recalls
- 🔍 **Authenticity Verification**: Real-time verification of medicine legitimacy
- 📋 **Recall Management**: Immediate recall capabilities for safety issues
- 📊 **Event Logging**: Complete audit trail of all supply chain events

## 🧑‍💼 Stakeholder Roles

- **Manufacturer** (Role 1): Creates and registers medicines
- **Distributor** (Role 2): Handles medicine distribution and transfers
- **Pharmacy** (Role 3): Dispenses medicines to patients
- **Patient** (Role 4): Receives and consumes medicines

## 📋 Medicine Status Types

- **Manufactured** (1): Newly created by manufacturer
- **In Transit** (2): Being transported between stakeholders
- **Delivered** (3): Arrived at destination
- **Dispensed** (4): Given to patient by pharmacy
- **Consumed** (5): Used by patient
- **Recalled** (6): Recalled for safety reasons

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/joeyfminc/Pharmaceutical-Supply-Chain-Tracker.git
cd Pharmaceutical-Supply-Chain-Tracker
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
clarinet test
```

## 💻 Usage Examples

### Register as a Stakeholder

```clarity
;; Register as a manufacturer
(contract-call? .MedSupply register-stakeholder u1 "PharmaCorp Inc")

;; Register as a distributor  
(contract-call? .MedSupply register-stakeholder u2 "MedDistribute LLC")

;; Register as a pharmacy
(contract-call? .MedSupply register-stakeholder u3 "City Pharmacy")

;; Register as a patient
(contract-call? .MedSupply register-stakeholder u4 "John Doe")
```

### Register a Medicine (Manufacturer Only)

```clarity
(contract-call? .MedSupply register-medicine 
  "Aspirin 100mg" 
  "BATCH-2024-001" 
  u1000 
  u2000 
  "Factory Floor A"
)
```

### Transfer Medicine Between Stakeholders

```clarity
;; Manufacturer to Distributor
(contract-call? .MedSupply transfer-medicine 
  u1 
  'SP2DISTRIBUTOR 
  "Warehouse B"
)

;; Distributor to Pharmacy
(contract-call? .MedSupply transfer-medicine 
  u1 
  'SP3PHARMACY 
  "Pharmacy Storage"
)
```

### Dispense Medicine to Patient

```clarity
(contract-call? .MedSupply dispense-medicine 
  u1 
  'SP4PATIENT 
  "PRESCRIPTION-12345"
)
```

### Update Medicine Status

```clarity
(contract-call? .MedSupply update-status 
  u1 
  u2 
  "Delivery Truck #5" 
  "In transit to pharmacy"
)
```

### Recall Medicine

```clarity
(contract-call? .MedSupply recall-medicine 
  u1 
  "Quality control issue detected"
)
```

## 🔍 Read-Only Functions

### Get Medicine Information

```clarity
(contract-call? .MedSupply get-medicine u1)
```

### Verify Medicine Authenticity

```clarity
(contract-call? .MedSupply verify-authenticity u1)
```

### Check if Medicine is Valid

```clarity
(contract-call? .MedSupply is-medicine-valid u1)
```

### Get Supply Chain Event

```clarity
(contract-call? .MedSupply get-supply-chain-event u1)
```

### Get Stakeholder Information

```clarity
(contract-call? .MedSupply get-stakeholder 'SP1MANUFACTURER)
```

## 🔐 Security Features

- **Role-Based Access Control**: Only authorized stakeholders can perform specific actions
- **Transfer Validation**: Ensures medicines follow proper supply chain flow
- **Expiry Date Checking**: Prevents dispensing of expired medicines
- **Recall Protection**: Recalled medicines cannot be transferred or dispensed
- **Immutable Records**: All events are permanently recorded on blockchain

## 🛡️ Error Codes

- `100`: Not authorized
- `101`: Invalid medicine data
- `102`: Medicine already exists
- `103`: Medicine not found
- `104`: Invalid status
- `105`: Invalid transfer
- `106`: Medicine already consumed

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Blockchain](https://stacks.org/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet)
- [Clarity Language Reference](https://docs.stacks.co/clarity)
