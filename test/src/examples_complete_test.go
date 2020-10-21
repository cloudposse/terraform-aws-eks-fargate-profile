package test

import (
	"context"
	"encoding/base64"
	"fmt"
	"k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/client-go/rest"
	"math/rand"
	"strconv"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	appsv1 "k8s.io/api/apps/v1"
	apiv1 "k8s.io/api/core/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/cache"

	"sigs.k8s.io/aws-iam-authenticator/pkg/token"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/eks"
)

func int32Ptr(i int32) *int32 { return &i }

func newClientset(cluster *eks.Cluster) (*kubernetes.Clientset, error) {
	gen, err := token.NewGenerator(true, false)
	if err != nil {
		return nil, err
	}
	opts := &token.GetTokenOptions{
		ClusterID: aws.StringValue(cluster.Name),
	}
	tok, err := gen.GetWithOptions(opts)
	if err != nil {
		return nil, err
	}
	ca, err := base64.StdEncoding.DecodeString(aws.StringValue(cluster.CertificateAuthority.Data))
	if err != nil {
		return nil, err
	}
	clientset, err := kubernetes.NewForConfig(
		&rest.Config{
			Host:        aws.StringValue(cluster.Endpoint),
			BearerToken: tok.Token,
			TLSClientConfig: rest.TLSClientConfig{
				CAData: ca,
			},
		},
	)
	if err != nil {
		return nil, err
	}
	return clientset, nil
}

// Test the Terraform module in examples/complete using Terratest.
func TestExamplesComplete(t *testing.T) {
	t.Parallel()

	rand.Seed(time.Now().UnixNano())

	randId := strconv.Itoa(rand.Intn(100000))
	attributes := []string{randId}

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../examples/complete",
		Upgrade:      true,
		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{"fixtures.us-east-2.tfvars"},
		Vars: map[string]interface{}{
			"attributes": attributes,
		},
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// If Go runtime crushes, run `terraform destroy` to clean up any resources that were created
	defer runtime.HandleCrash(func(i interface{}) {
		terraform.Destroy(t, terraformOptions)
	})

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the value of an output variable
	vpcCidr := terraform.Output(t, terraformOptions, "vpc_cidr")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "172.16.0.0/16", vpcCidr)

	// Run `terraform output` to get the value of an output variable
	privateSubnetCidrs := terraform.OutputList(t, terraformOptions, "private_subnet_cidrs")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, []string{"172.16.0.0/19", "172.16.32.0/19"}, privateSubnetCidrs)

	// Run `terraform output` to get the value of an output variable
	publicSubnetCidrs := terraform.OutputList(t, terraformOptions, "public_subnet_cidrs")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, []string{"172.16.96.0/19", "172.16.128.0/19"}, publicSubnetCidrs)

	// Run `terraform output` to get the value of an output variable
	eksClusterId := terraform.Output(t, terraformOptions, "eks_cluster_id")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-"+randId+"-cluster", eksClusterId)

	// Run `terraform output` to get the value of an output variable
	eksNodeGroupId := terraform.Output(t, terraformOptions, "eks_node_group_id")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-"+randId+"-cluster:eg-test-eks-fargate-"+randId+"-workers", eksNodeGroupId)

	// Run `terraform output` to get the value of an output variable
	eksNodeGroupRoleName := terraform.Output(t, terraformOptions, "eks_node_group_role_name")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-"+randId+"-workers", eksNodeGroupRoleName)

	// Run `terraform output` to get the value of an output variable
	eksNodeGroupStatus := terraform.Output(t, terraformOptions, "eks_node_group_status")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "ACTIVE", eksNodeGroupStatus)

	// Run `terraform output` to get the value of an output variable
	eksFargateProfileId := terraform.Output(t, terraformOptions, "eks_fargate_profile_id")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-"+randId+"-cluster:eg-test-eks-fargate-"+randId+"-fargate", eksFargateProfileId)

	// Run `terraform output` to get the value of an output variable
	eksFargateProfileRoleName := terraform.Output(t, terraformOptions, "eks_fargate_profile_role_name")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-"+randId+"-fargate-default", eksFargateProfileRoleName)

	// Run `terraform output` to get the value of an output variable
	eksFargateProfileStatus := terraform.Output(t, terraformOptions, "eks_fargate_profile_status")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "ACTIVE", eksFargateProfileStatus)

	// Wait for the worker nodes to join the cluster
	// https://github.com/kubernetes/client-go
	// https://www.rushtehrani.com/post/using-kubernetes-api
	// https://rancher.com/using-kubernetes-api-go-kubecon-2017-session-recap
	// https://gianarb.it/blog/kubernetes-shared-informer
	// https://stackoverflow.com/questions/60547409/unable-to-obtain-kubeconfig-of-an-aws-eks-cluster-in-go-code/60573982#60573982
	fmt.Println("Waiting for worker nodes to join the EKS cluster...")

	clusterName := "eg-test-eks-fargate-" + randId + "-cluster"
	region := "us-east-2"

	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String(region),
	}))

	eksSvc := eks.New(sess)

	input := &eks.DescribeClusterInput{
		Name: aws.String(clusterName),
	}

	result, err := eksSvc.DescribeCluster(input)
	assert.NoError(t, err)

	clientset, err := newClientset(result.Cluster)
	assert.NoError(t, err)

	// Create Kubernetes deployment in the `default` namespace (for which we create a Fargate Profile)
	// https://github.com/kubernetes/client-go/blob/master/examples/create-update-delete-deployment/main.go
	fmt.Println("Creating Kubernetes deployment 'demo-deployment' in the 'default' namespace...")
	deploymentsClient := clientset.AppsV1().Deployments(apiv1.NamespaceDefault)

	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Namespace: apiv1.NamespaceDefault,
			Name:      "demo-deployment",
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": "demo",
				},
			},
			Template: apiv1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app": "demo",
					},
				},
				Spec: apiv1.PodSpec{
					Containers: []apiv1.Container{
						{
							Name:  "web",
							Image: "nginx:1.17",
							Ports: []apiv1.ContainerPort{
								{
									Name:          "http",
									Protocol:      apiv1.ProtocolTCP,
									ContainerPort: 80,
								},
							},
						},
					},
				},
			},
		},
	}

	deploymentClient, err := deploymentsClient.Create(context.TODO(), deployment, metav1.CreateOptions{})
	assert.NoError(t, err)
	fmt.Printf("Created Kubernetes deployment %q\n", deploymentClient.GetObjectMeta().GetName())

	factory := informers.NewSharedInformerFactory(clientset, 0)
	informer := factory.Core().V1().Nodes().Informer()
	stopChannel := make(chan struct{})
	var countOfWorkerNodes uint64 = 0

	informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			node := obj.(*corev1.Node)
			fmt.Printf("Node %s has joined the EKS cluster at %s\n", node.Name, node.CreationTimestamp)
			atomic.AddUint64(&countOfWorkerNodes, 1)
			if countOfWorkerNodes == 3 {
				close(stopChannel)
			}
		},
	})

	go informer.Run(stopChannel)

	select {
	case <-stopChannel:
		fmt.Println("All nodes have joined the EKS cluster")
		fmt.Printf("Listing deployments in namespace '%q':\n", apiv1.NamespaceDefault)
		list, err := deploymentsClient.List(context.TODO(), metav1.ListOptions{})
		assert.NoError(t, err)

		for _, d := range list.Items {
			fmt.Printf("* Deployment '%s' has %d replica(s)\n", d.Name, *d.Spec.Replicas)
		}

		fmt.Println("Deleting deployment 'demo-deployment' ...")
		deletePolicy := metav1.DeletePropagationForeground
		err = deploymentsClient.Delete(context.TODO(), "demo-deployment", metav1.DeleteOptions{
			PropagationPolicy: &deletePolicy,
		})
		assert.NoError(t, err)
		fmt.Println("Deleted deployment 'demo-deployment'")

	case <-time.After(8 * time.Minute):
		msg := "NOT all nodes have joined the EKS cluster"
		fmt.Println(msg)
		assert.Fail(t, msg)
	}
}
