# frozen_string_literal: true

module V1
  class DocumentsController < ApplicationController
    def index
      person = ResourceVisibility.people.find(params[:person_id])
      documents = person.documents.where(superseded_at: nil).with_attached_file.order(created_at: :desc, id: :desc)
      render json: { data: documents.map { |document| serialize(document) } }
    end

    def create
      person = ResourceVisibility.people.find(params[:person_id])
      file = params[:file]
      if file.is_a?(ActionDispatch::Http::UploadedFile)
        raise ArgumentError, "file too large" if file.size > DocumentUploader::MAX_BYTES
        filename, content_type, io = file.original_filename, file.content_type, file.tempfile
      else
        input = params.require(:document).permit(:filename, :content_type, :content_base64)
        encoded = input[:content_base64].to_s
        raise ArgumentError, "file too large" if encoded.bytesize > ((DocumentUploader::MAX_BYTES + 2) / 3) * 4
        filename, content_type, io = input[:filename], input[:content_type], StringIO.new(Base64.strict_decode64(encoded))
      end
      with_idempotency do
        document = DocumentUploader.call(person: person, filename: filename,
          content_type: content_type, io: io, replace: true)
        render json: serialize(document), status: :created
      end
    rescue ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "invalid_document", title: error.message)
    end

    def show
      person = ResourceVisibility.people.find(params[:person_id])
      document = person.documents.find(params[:id])
      raise ActiveRecord::RecordNotFound unless document.downloadable?

      inline = params[:download] != "true" && document.content_type.in?(%w[application/pdf text/plain])
      send_data document.download!, filename: document.filename,
        type: document.content_type.in?(DocumentUploader::TYPES) ? document.content_type : "application/octet-stream",
        disposition: inline ? "inline" : "attachment"
    rescue ActiveStorage::FileNotFoundError
      render_problem(status: :not_found, code: "document_not_available", title: "File not available")
    end

    private

    def serialize(document)
      document.as_json(only: %i[id filename content_type byte_size scan_status created_at]).merge(
        "downloadable" => document.downloadable?
      )
    end
  end
end
