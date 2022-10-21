//
//  InvoiceVC.swift
//  ClientWindowCounter
//
//  Created by Matthew Rawlings on 10/7/22.
//

import UIKit

struct ShadowLineItem {
    var quantity: Int64
    var product: Product
    var invoice: Invoice
}

class InvoiceVC: UIViewController {
    
    //MARK: - Properties
    var isNewInvoice = false
    var invoice: Invoice?
    var client: Client?
    var product: Product?
    private var lineItems: [LineItem] = []
    var shadowLineItems: [ShadowLineItem] = []
    
    var discountChosen: Double = 1.0
    
    //MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var productDescription: UITextField!
    @IBOutlet weak var totalPriceLabel: UILabel!
    @IBOutlet weak var discountSegmentControl: UISegmentedControl!
    
    //MARK: - Lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        title = isNewInvoice ? "New Invoice" : "Invoice Details"
        setupView()
        createShadowLineItem(lineItems: lineItems)
        tableView.reloadData()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    //MARK: - ACTION
    @IBAction func discountToggleAdjusted(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            discountChosen = 1.0
        case 1:
            discountChosen = 0.9
        case 2:
            discountChosen = 0.85
        case 3:
            discountChosen = 0.8
        default:
            discountChosen = 1.0
        }
        let calculatedPrice = String(format: "$%.2f", calculateTotal())
        totalPriceLabel.text = calculatedPrice
    }
    
    @IBAction func saveButtonTapped(_ sender: UIBarButtonItem) {
        guard let invoice
        else { return }
        invoice.invoiceDescription = productDescription.text
        invoice.totalPrice = calculateTotal()
        invoice.discount = discountChosen
        if isNewInvoice {
            InvoiceController.shared.save(invoice: invoice)
        } else {
            for (index, shadowLineItem) in shadowLineItems.enumerated() {
                lineItems[index].quantity = shadowLineItem.quantity
            }
            InvoiceController.shared.updateInvoice(invoice: invoice, discount: discountChosen, totalPrice: invoice.totalPrice, invoiceDescription: invoice.invoiceDescription ?? "", client: client!)
        }
        navigationController?.popViewController(animated: true)
    }
    
    //MARK: - HELPER METHODS
    private func setupView() {
        if isNewInvoice,
           let client = client {
            let invoice = Invoice(discount: 1.0, totalPrice: 0.00, invoiceDescription: "", client: client)
            self.invoice = invoice
            let lineItems = ProductController.shared.products.map { LineItem(quantity: 0, product: $0, invoice: invoice) }
            self.lineItems = lineItems
        } else if !isNewInvoice {
            guard let lineItemsSet = invoice?.lineItems else { return }
            guard var lineItems = (lineItemsSet.allObjects as? [LineItem])
            else { return }
            
            lineItems.sort { lhs, rhs in
                guard let lhsDate = lhs.product?.creationDate,
                      let rhsDate = rhs.product?.creationDate
                else { return true }
                
                return lhsDate < rhsDate
            }
            
            self.lineItems = lineItems
            guard let invoice else { return }

            discountChosen = invoice.discount //test
            switch Double(invoice.discount) {
            case 1.0:
                discountSegmentControl.selectedSegmentIndex = 0
            case 0.9:
                discountSegmentControl.selectedSegmentIndex = 1
            case 0.85:
                discountSegmentControl.selectedSegmentIndex = 2
            case 0.8:
                discountSegmentControl.selectedSegmentIndex = 3
            default:
                discountSegmentControl.selectedSegmentIndex = 0
            }
            self.productDescription.text = invoice.invoiceDescription
            self.totalPriceLabel.text = String(format: "$%.2f", invoice.totalPrice)
        }
        tableView.reloadData()
    }
    
    func calculateTotal() -> Double {
        var sum = 0.0
        if isNewInvoice {
            for lineItem in lineItems {
                let quantity = Double(lineItem.quantity)
                let price = (lineItem.product?.price) ?? 0.0
                sum += quantity * price
            }
        } else {
            for shadowLineItem in shadowLineItems {
                let quantity = Double(shadowLineItem.quantity)
                let price = (shadowLineItem.product.price)
                sum += quantity * price
            }
        }
        sum = sum * discountChosen
        return sum
    }
    
    func createShadowLineItem(lineItems: [LineItem]) {
        for lineItem in lineItems {
            guard let product = lineItem.product,
                  let invoice = lineItem.invoice
            else { return }
            let lineItemCopy = ShadowLineItem.init(quantity: lineItem.quantity, product: product, invoice: invoice)
            shadowLineItems.append(lineItemCopy)
        }
        
    }
}

    //MARK: - TABLEVIEW METHODS
extension InvoiceVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        lineItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "lineItemCell", for: indexPath) as? InvoiceTableViewCell else { return UITableViewCell() }
        
        if isNewInvoice {
            let lineItem = lineItems[indexPath.row]
            
            cell.delegate = self
            
            cell.updateViews(with: lineItem)
        } else if !isNewInvoice {
            let lineItem = shadowLineItems[indexPath.row]

            cell.delegate = self
            
            cell.updateViews(with: lineItem)
        }
        
        return cell
    }
}

    //MARK: - INVOICE CELL DELEGATE
extension InvoiceVC: InvoiceTableViewCellDelegate {
    func shadowStepperValueChanged(for shadowLineItem: ShadowLineItem) {
        if let oldShadowLineIndex = shadowLineItems.firstIndex(where: {$0.product.productName == shadowLineItem.product.productName}) {
            shadowLineItems[oldShadowLineIndex] = shadowLineItem
        }
        let calculatedPrice = String(format: "$%.2f", calculateTotal())
        totalPriceLabel.text = calculatedPrice
    }
    
    func stepperValueChanged() {
        let calculatedPrice = String(format: "$%.2f", calculateTotal())
        totalPriceLabel.text = calculatedPrice
    }
}
