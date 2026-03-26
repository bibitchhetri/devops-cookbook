# Use official Node.js LTS image as base
FROM node:20-alpine

# Set working directory in container
WORKDIR /usr/src/app

# Copy package files first (for caching)
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy source code
COPY . .

# Expose port the app runs on
EXPOSE 3000

# Command to start the app
CMD ["node", "app.js"]
