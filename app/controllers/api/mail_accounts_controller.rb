class Api::MailAccountsController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/mail_accounts
  def index
    @mail_accounts = MailAccount.ordered
    render json: @mail_accounts.map { |ma| mail_account_json(ma) }
  end

  # POST /api/mail_accounts
  def create
    @mail_account = MailAccount.new(mail_account_params)
    if @mail_account.save
      render json: mail_account_json(@mail_account), status: :created
    else
      render json: { errors: @mail_account.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/mail_accounts/:id
  def update
    @mail_account = MailAccount.find(params[:id])
    if @mail_account.update(mail_account_params)
      render json: mail_account_json(@mail_account)
    else
      render json: { errors: @mail_account.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/mail_accounts/:id
  def destroy
    @mail_account = MailAccount.find(params[:id])
    @mail_account.destroy
    head :no_content
  end

  private

  def mail_account_params
    params.permit(:email, :provider, :provider_url, :password, :imap_server, :imap_port, :smtp_server, :smtp_port)
  end

  def mail_account_json(mail_account)
    {
      id: mail_account.id,
      email: mail_account.email,
      provider: mail_account.provider,
      provider_url: mail_account.provider_url,
      password: mail_account.password.present? ? "••••••••" : nil,
      imap_server: mail_account.imap_server,
      imap_port: mail_account.imap_port,
      smtp_server: mail_account.smtp_server,
      smtp_port: mail_account.smtp_port,
      created_at: mail_account.created_at,
      updated_at: mail_account.updated_at
    }
  end
end
