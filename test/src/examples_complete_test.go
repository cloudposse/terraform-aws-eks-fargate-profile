package test

import (
	"fmt"
	"k8s.io/apimachinery/pkg/util/runtime"
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
	"k8s.io/client-go/tools/clientcmd"
)

func int32Ptr(i int32) *int32 { return &i }

// Test the Terraform module in examples/complete using Terratest.
func TestExamplesComplete(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../examples/complete",
		Upgrade:      true,
		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{"fixtures.us-east-2.tfvars"},
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
	assert.Equal(t, "eg-test-eks-fargate-cluster", eksClusterId)

	// Run `terraform output` to get the value of an output variable
	eksNodeGroupId := terraform.Output(t, terraformOptions, "eks_node_group_id")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-cluster:eg-test-eks-fargate-workers", eksNodeGroupId)

	// Run `terraform output` to get the value of an output variable
	eksNodeGroupRoleName := terraform.Output(t, terraformOptions, "eks_node_group_role_name")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-workers", eksNodeGroupRoleName)

	// Run `terraform output` to get the value of an output variable
	eksNodeGroupStatus := terraform.Output(t, terraformOptions, "eks_node_group_status")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "ACTIVE", eksNodeGroupStatus)

	// Run `terraform output` to get the value of an output variable
	eksFargateProfileId := terraform.Output(t, terraformOptions, "eks_fargate_profile_id")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-cluster:eg-test-eks-fargate-fargate", eksFargateProfileId)

	// Run `terraform output` to get the value of an output variable
	eksFargateProfileRoleName := terraform.Output(t, terraformOptions, "eks_fargate_profile_role_name")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "eg-test-eks-fargate-fargate", eksFargateProfileRoleName)

	// Run `terraform output` to get the value of an output variable
	eksFargateProfileStatus := terraform.Output(t, terraformOptions, "eks_fargate_profile_status")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "ACTIVE", eksFargateProfileStatus)

	// Wait for Node Group nodes to join the cluster
	// https://github.com/kubernetes/client-go
	// https://www.rushtehrani.com/post/using-kubernetes-api
	// https://rancher.com/using-kubernetes-api-go-kubecon-2017-session-recap
	// https://gianarb.it/blog/kubernetes-shared-informer
	// https://medium.com/@muhammet.arslan/write-your-own-kubernetes-controller-with-informers-9920e8ab6f84
	fmt.Println("Waiting for Node Group nodes to join the EKS cluster...")

	kubeconfigPath := "/.kube/config"
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfigPath)
	assert.NoError(t, err)

	clientset, err := kubernetes.NewForConfig(config)
	assert.NoError(t, err)

	factory := informers.NewSharedInformerFactory(clientset, 0)
	informer := factory.Core().V1().Nodes().Informer()
	stopChannel := make(chan struct{})

	var countOfWorkerNodes uint64 = 0

	informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			node := obj.(*corev1.Node)
			fmt.Printf("Node Group node %s has joined the EKS cluster at %s\n", node.Name, node.CreationTimestamp)
			atomic.AddUint64(&countOfWorkerNodes, 1)
			if countOfWorkerNodes == 2 {
				informer = nil
				close(stopChannel)
			}
		},
	})

	continueAfterNodeGroupNodesJoinedCluster := false
	go informer.Run(stopChannel)

	select {
	case <-stopChannel:
		fmt.Println("All Node Group nodes have joined the EKS cluster")
		continueAfterNodeGroupNodesJoinedCluster = true
	case <-time.After(5 * time.Minute):
		msg := "NOT all Node Group nodes have joined the EKS cluster"
		fmt.Println(msg)
		assert.Fail(t, msg)
	}

	if continueAfterNodeGroupNodesJoinedCluster {
		// Deploy an image to Kubernetes `default` namespace (for which we create a Fargate Profile) and wait for a Fargate node to join the cluster
		// https://github.com/kubernetes/client-go/blob/master/examples/create-update-delete-deployment/main.go
		fmt.Println("Creating Kubernetes deployment in the 'default' namespace...")
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

		result, err := deploymentsClient.Create(deployment)
		assert.NoError(t, err)
		fmt.Printf("Created Kubernetes deployment %q\n", result.GetObjectMeta().GetName())

		fmt.Println("Waiting for a Fargate node to join the EKS cluster...")
		factory2 := informers.NewSharedInformerFactory(clientset, 0)
		informer2 := factory2.Core().V1().Nodes().Informer()
		stopChannel2 := make(chan struct{})

		informer2.AddEventHandler(cache.ResourceEventHandlerFuncs{
			AddFunc: func(obj interface{}) {
				node := obj.(*corev1.Node)
				fmt.Printf("Fargate node %s has joined the EKS cluster at %s\n", node.Name, node.CreationTimestamp)
				informer2 = nil
				close(stopChannel2)
			},
		})

		go informer2.Run(stopChannel2)

		select {
		case <-stopChannel2:
			fmt.Println("All Fargate nodes have joined the EKS cluster")
			fmt.Printf("Listing deployments in namespace %q\n", apiv1.NamespaceDefault)
			list, err := deploymentsClient.List(metav1.ListOptions{})
			assert.NoError(t, err)

			for _, d := range list.Items {
				fmt.Printf("Deployment %s has %d replicas\n", d.Name, *d.Spec.Replicas)
			}

			fmt.Println("Deleting deployment...")
			deletePolicy := metav1.DeletePropagationForeground
			err = deploymentsClient.Delete("demo-deployment", &metav1.DeleteOptions{
				PropagationPolicy: &deletePolicy,
			})
			assert.NoError(t, err)
			fmt.Println("Deleted deployment")

		case <-time.After(5 * time.Minute):
			msg := "NOT all Fargate nodes have joined the EKS cluster"
			fmt.Println(msg)
			assert.Fail(t, msg)
		}
	}
}
