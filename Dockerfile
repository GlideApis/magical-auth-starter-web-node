FROM node:18 as build

WORKDIR /app

COPY package.json /app
RUN npm install

COPY . /app
RUN npm run build

FROM node:18

WORKDIR /app

COPY --from=build /app/build /app
COPY --from=build /app/src/static /app/static
COPY --from=build /app/package.json /app/package.json

RUN npm install --omit=dev

CMD ["node", "index.js"]
