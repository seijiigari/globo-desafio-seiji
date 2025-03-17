DESAFIO GLOBO - Seiji


Arquitetura Atual

A arquitetura atual é composta por: 

- Uma VPC nomeada como vpc-poc;
- Uma subnet pública onde os recursos podem ser acessados diretamente da internet.
- Aplicação em Python: Aplicação Python hospedada em uma EC2 na subnet pública.
- Um NAT Gateway: Permitindo que instâncias em subnet privadas se conectem à internet ou outros serviços AWS.
- Internet Gateway: Facilita a comunicação entre a VPC e a internet.
- Um ambiente Elastic Beanstalk: Hospeda a aplicação em Node, e foi utilizado para apresentar outra forma de servir a aplicação;
- Aplicação em Node.js:  Hospedada no Elastic Beanstalk, que gerencia automaticamente a implantação, dimensionamento e operação da aplicação.
- Dois bucket S3: Um para armazenar as versões da aplicação em Node. Outro para salvar o terraform.tfstate, que guarda o estado da infra como código.

Passo a passo
- Faça o clone do repositorio: git clone git@github.com:seijiigari/globo-desafio-seiji.git
- Configure o acesso programatico a sua conta AWS.
- Acesse o diretorio src
- Execute o comando terraform init
- Execute o comando terraform plan
- Execute o comando terraform apply
- Acesse as aplicações utilizando o IP e endpoint do Beanstalk apresentados no output.

OBS: Ambas aplicações só respondem em HTTP (Porta 80)


Melhoria Futura

Na arquitetura futura, proponho as seguintes alterações:

- Nenhuma aplicação ficará em subnets públicas. 
- As aplicações serão criadas em recursos hospedados na subnet privada
- Ambas serão servidas atráves de um ALB que fará a interfarce com o usuário
- O cache da aplicação em Python não mais tratado no código e passar a ser gerenciado por um Redis.
- O cache da aplicação em Node.js não será mais tratado no código e passará a ser gerenciado pelo API Gateway.
- Os Aplications load balancers serão configurados com certificado gerado no AWS Certificate Manger.
- Habilitar as Actions ja existentes no repositório Github.




