# encoding: utf-8

module SEPA
  class CreditTransfer < Message
    self.account_class = DebtorAccount
    self.transaction_class = CreditTransferTransaction
    self.xml_main_tag = 'CstmrCdtTrfInitn'
    self.known_schemas = [ PAIN_001_003_03, PAIN_001_002_03, PAIN_001_001_03 ]

  private
    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        batch_booking:  transaction.batch_booking,
        service_level:  transaction.service_level,
        currency: transaction.currency
      }
    end

    def build_payment_informations(builder)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        # All transactions with the same requested_date are placed into the same PmtInf block
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('TRF')
          builder.BtchBookg(group[:batch_booking])
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum('%.2f' % amount_total(transactions))
          builder.ReqdExctnDt(group[:requested_date].iso8601)
          builder.Dbtr do
            builder.Nm(account.name)
            builder.PstlAdr do
              builder.Ctry(account.country)
              builder.AdrLine(account.address_line)
            end
          end
          builder.DbtrAcct do
            builder.Id do
              builder.IBAN(account.iban)
            end
          end
          builder.DbtrAgt do
            builder.FinInstnId do
              if account.bic
                builder.BIC(account.bic)
              else
                builder.Othr do
                  builder.Id('NOTPROVIDED')
                end
              end
            end
          end

          transactions.each do |transaction|
            build_transaction(builder, transaction)
          end
        end
      end
    end

    def build_transaction(builder, transaction)
      builder.CdtTrfTxInf do
        builder.PmtId do
          builder.InstrId(transaction.instruction_id)
          builder.EndToEndId(transaction.reference)
        end
        unless transaction.service_level.nil?
          builder.PmtTpInf do
            builder.SvcLvl do
              builder.Cd(transaction.service_level)
            end
          end
        end
        #builder.ChrgBr('SLEV')
        builder.Amt do
          builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
        end
        if transaction.bic
          builder.CdtrAgt do
            builder.FinInstnId do
              builder.BIC(transaction.bic)
            end
          end
        end
        builder.Cdtr do
          builder.Nm(transaction.name)
          if !transaction.address_line1.blank? || !transaction.address_line2.blank?
            builder.PstlAdr do
              builder.AdrLine(transaction.address_line1) unless transaction.address_line1.blank?
              builder.AdrLine(transaction.address_line2) unless transaction.address_line2.blank?
            end
          end
        end
        builder.CdtrAcct do
          builder.Id do
            builder.IBAN(transaction.iban)
          end
        end
        if transaction.remittance_information
          builder.RmtInf do
            builder.Ustrd(transaction.remittance_information)
          end
        elsif transaction.creditor_reference
          builder.RmtInf do
            builder.Strd do
              builder.CdtrRefInf do
                builder.Tp do
                  builder.CdOrPrtry do
                    builder.Cd("SCOR")
                  end
                end
                builder.Ref(transaction.creditor_reference)
              end
            end
          end
        end
      end
    end
  end
end
