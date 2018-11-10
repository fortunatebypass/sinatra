FROM ruby:2.5-alpine
COPY . /app
RUN cd /app && \
    bundle install
CMD cd /app && bundle exec rackup -o 0.0.0.0
EXPOSE 9292
