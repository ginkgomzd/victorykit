require 'json'

class DonationTrackingController < ApplicationController

  def create
    win!(:donation)
    donation = Donation.create({
      referral_code: ReferralCode.find_by_code(params[:referral_code]),
      member: Signature.find_by_id(params[:signature_id]).try(:member),
      petition: Petition.find_by_id(params[:petition_id])
    })
    render(:nothing => true, :status => donation.valid? ? 200 : 500)
  end

  def paypal
    if Paypal.verify_payment(params)
      Donation.confirm_payment(params[:payment_gross], params[:payer_email])
      render(:nothing => true, :status => 200)
    else
      render(:nothing => true, :status => 500)
    end
  end

end
