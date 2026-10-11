FROM oven/bun:1.4-alpine

WORKDIR /app
COPY server.ts ./
COPY public ./public

# O commit que gerou a imagem, para a página mostrar qual versão está no ar.
ARG VERSAO=dev
ENV VERSAO=$VERSAO NODE_ENV=production

USER bun
EXPOSE 3000
CMD ["bun", "server.ts"]
