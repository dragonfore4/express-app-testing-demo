FROM node:16-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run test

EXPOSE 3000

CMD ["npm", "start"]
