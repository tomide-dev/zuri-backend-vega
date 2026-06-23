# ==================================
# Backend Dockerfile
# ==================================

# Use lightweight Node.js image
FROM node:20-alpine

# Create application directory
WORKDIR /app

# Copy dependency definitions
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy application source code
COPY . .

# Application listens on port 5000
EXPOSE 5000

# Start Express application
CMD ["npm", "start"]