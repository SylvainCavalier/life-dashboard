module Api
  # Page Courses : la liste unique. `POST` accepte un nom (`shopping_item[name]`) ou
  # plusieurs (`names`, depuis une carte ou une saisie « lait, oeufs ») ; un article
  # deja present est ignore, pas refuse. `DELETE /clear` vide la liste apres les courses.
  class ShoppingItemsController < ApplicationController
    before_action :set_item, only: [:update, :destroy]

    # GET /api/shopping_items
    def index
      render json: ShoppingItem.ordered.map(&:api_attributes)
    end

    def create
      names = params[:names].presence || [params.dig(:shopping_item, :name)]
      added, skipped = ShoppingItem.add_names(Array(names))
      render json: { added: added.map(&:api_attributes), skipped: skipped }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    # PATCH : `checked` (coche en magasin) et/ou `name`
    def update
      attributes = params.require(:shopping_item).permit(:name)
      if params[:shopping_item].key?(:checked)
        attributes[:checked_at] = ActiveModel::Type::Boolean.new.cast(params[:shopping_item][:checked]) ? Time.current : nil
      end

      if @item.update(attributes)
        render json: @item.api_attributes
      else
        render json: { errors: @item.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy
      head :no_content
    end

    # DELETE /api/shopping_items/clear
    def clear
      render json: { removed: ShoppingItem.clear! }
    end

    private

    def set_item
      @item = ShoppingItem.find(params[:id])
    end
  end
end
