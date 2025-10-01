Hojhon site - CI-only repo

This repository stores the static site and a minimal Docker image build workflow. The Actions workflow builds and pushes a Docker image (nginx) containing the committed site files.

Required GitHub repository secrets
- DOCKER_REGISTRY (e.g. docker.io)
- DOCKER_REPOSITORY (e.g. youruser/hojhon-site)
- DOCKER_USERNAME
- DOCKER_PASSWORD (use a registry token when possible)
- FORMSPREE_FORM_ID (Formspree form ID; not committed)

How it works
- Push to `main` triggers GitHub Actions to build the Docker image and push it to your registry.
- The image is tagged as `:latest` (and you can add additional tags if you want).

Pull and run locally
1. Pull the image that was pushed by the workflow (example uses Docker Hub):

```bash
docker pull docker.io/<your-username-or-org>/<repo>:latest
```

2. Run the container locally, passing your Formspree ID at runtime so the contact form uses your form (replace the value with your actual form id):

```bash
docker run --rm -p 8080:80 -e FORMSPREE_FORM_ID="xanpozrj" docker.io/<your-username-or-org>/<repo>:latest
# then open http://localhost:8080 in your browser
```

Notes
- The repository's `index.html` contains a placeholder URL which is replaced at container startup by `docker-entrypoint.sh` using the `FORMSPREE_FORM_ID` environment variable. This keeps the form ID out of source control.
- If you prefer the build to bake the actual Formspree URL into the image, we can change the workflow to inject the secret at build time, but that will store the form ID inside the image layers.

Extending to GitOps / ArgoCD
- If you later want automated deployments into Kubernetes via ArgoCD, we can add a manifests folder and a small GitHub Action to update image tags and trigger ArgoCD sync.
